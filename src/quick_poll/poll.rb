# frozen_string_literal: true

require 'unicode/emoji'

class String
  def emoji?
    return true if self =~ /^<:.+:\d+>$/
    !!(self =~ /^#{Unicode::Emoji::REGEX_WELL_FORMED_INCLUDE_TEXT}$/)
  end
end

module QuickPoll
  class Poll
    include Base

    MAX_OPTIONS = 20
    DEFAULT_EMOJIS = [
      "🇦", "🇧", "🇨", "🇩", "🇪",
      "🇫", "🇬", "🇭", "🇮", "🇯",
      "🇰", "🇱", "🇲", "🇳", "🇴",
      "🇵", "🇶", "🇷", "🇸", "🇹",
    ].freeze

    def self.events(bot)
      @@last_reactions = Hash.new { |h, k| h[k] = {} }
      @@checked_message = []

      bot.reaction_add { |event| exclude_reaction(event) }

      bot.reaction_remove do |event|
        message_id = event.instance_variable_get(:@message_id)
        user = event.user
        next unless reacted = @@last_reactions[message_id][user.id]
        @@last_reactions[message_id][user.id] = "" if event.emoji.to_reaction == reacted
      end
    end

    def self.exclude_reaction(event)
      message_id = event.instance_variable_get(:@message_id)
      return unless is_poll?(event, message_id)

      user = event.user
      emoji = event.emoji
      reacted = @@last_reactions[message_id][user.id]
      @@last_reactions[message_id][user.id] = emoji.to_reaction

      if reacted
        Discordrb::API::Channel.delete_user_reaction(
          event.bot.token, event.channel.id, message_id, reacted, user.id
        ) rescue nil if reacted != ""
      else
        message = event.message
        message.reactions.each do |reaction|
          next if @@last_reactions[message.id][user.id] == reaction.to_s
          message.delete_reaction(user, reaction.to_s) rescue nil
        end
      end
    end

    def self.is_poll?(event, message_id)
      return true if @@checked_message.include?(message_id)

      message = event.message
      poll_embed = message.embeds[0]
    rescue
      return false
    else
      return false unless message.from_bot? && poll_embed.color == COLOR_EXPOLL

      @@checked_message << message_id
      true
    end

    def initialize(event, prefix, exclusive, args, response)
      @exclusive = exclusive
      @prefix = prefix
      @author = event.author
      @server = event.server
      @channel = event.channel
      @message = event.message
      @response = response

      return unless parse_command(args)

      return unless check_external_emoji

      return if exclusive && !can_exclusive

      @response.edit("", poll_embed)
      add_reactions
    end

    private

    def parse_command(args)
      @command, @query = args.shift(2)

      begin
        @options = parse_args(args)
      rescue TooFewArguments
        args_error = "選択肢の数が指定されていません"
      rescue TooFewOptions
        args_error = "選択肢が1個を下回っています"
      rescue TooManyOptions
        args_error = "選択肢が20個を超えています"
      rescue DuplicateEmojis
        args_error = "絵文字が重複しています"
      end

      if args_error
        @response.delete
        @response = send_error(args_error)
        return false
      end

      true
    end

    def can_exclusive
      if @channel.private?
        @response.delete
        @response = send_error(
          "DM・グループDM内では 'ex#{@prefix}' プレフィックスが利用できません"
        )
        return false
      end

      unless @server&.bot.permission?(:manage_messages, @channel)
        @response.delete
        @response = send_error(
          "'ex#{@prefix}' プレフィックスが利用できません",
          "`ex#{@prefix}` プレフィックスコマンドの実行にはBOTに **メッセージの管理** 権限が必要です"
        )
        return false
      end

      true
    end

    class TooFewArguments < StandardError; end
    class TooFewOptions < StandardError; end
    class TooManyOptions < StandardError; end
    class DuplicateEmojis < StandardError; end

    def parse_args(args)
      case @command
      when "freepoll"
        return {}
      when "numpoll"
        raise TooFewArguments if args.empty?

        num = args[0].tr("０-９", "0-9").to_i
        raise TooFewOptions if num < 1
        raise TooManyOptions if num > MAX_OPTIONS

        return DEFAULT_EMOJIS[0...num].zip([]).to_h
      end

      return { "⭕" => nil, "❌" => nil } if args.empty?
      raise TooManyOptions if args.size > MAX_OPTIONS * 2

      if args.all?(&:emoji?)
        raise TooManyOptions if args.size > MAX_OPTIONS
        raise DuplicateEmojis if args.size > args.uniq.size
        return args.zip([]).to_h
      end

      emojis, opts = args.partition.with_index { |_, i| i.even? }

      if args.size.even? && emojis.all?(&:emoji?)
        raise TooManyOptions if emojis.size > MAX_OPTIONS
        raise DuplicateEmojis if emojis.size > emojis.uniq.size
        return emojis.zip(opts).to_h
      end

      raise TooManyOptions if args.size > MAX_OPTIONS
      return DEFAULT_EMOJIS[0...args.size].zip(args).to_h
    end

    def check_external_emoji
      return true if @channel.private? || @server.bot.permission?(:use_external_emoji, @channel)

      external = @options.keys.find do |emoji|
        next if emoji !~ /<a?:.+:(\d+)>/
        !@server.emojis[$1.to_i]
      end

      if external
        @response.delete
        @response = send_error(
          "外部の絵文字が利用できません",
          "投票に外部の絵文字を使用したい場合、BOTに **外部の絵文字の使用** 権限が必要です"
        )
        return false
      end

      true
    end

    def poll_embed
      embed = Discordrb::Webhooks::Embed.new

      embed.color = @exclusive ? COLOR_EXPOLL : COLOR_POLL
      embed.title = "📊 #{@query}\u200c"

      embed.description = @options.map do |emoji, opt|
        "\u200B#{emoji} #{opt}\u200C" if opt
      end.compact.join("\n")
      embed.description += "\n\n投票結果は `#{@prefix}sumpoll #{@response.id}` で集計"

      embed.author = {
        icon_url: @author.avatar_url,
        name: @author.respond_to?(:display_name) ? @author.display_name : @author.distinct
      }
      embed.image = { url: get_with_image }
      embed.footer = { text: footer_text }

      embed
    end

    def get_with_image
      @message.attachments.find do |attachment|
        next if attachment.height.nil?
        attachment.filename.end_with?('.png', '.jpg', '.jpeg', '.gif', '.webp')
      end&.proxy_url
    end

    def footer_text
      case @command
      when "poll", "numpoll"
        "選択肢にリアクションで#{"1人1票だけ" if @exclusive}投票できます"
      when "freepoll"
        "任意のリアクションで#{"1人1票だけ" if @exclusive}投票できます"
      end
    end

    def add_reactions
      @options.keys.each { |emoji| @response.react(emoji =~ /<a?:(.+:\d+)>/ ? $1 : emoji) }
    rescue
      @response.delete
      @response = send_error(
        "投票を作成できません",
        "投票を作成するには、BOTに **メッセージ履歴を読む** と **リアクションの追加** 権限が必要です"
      )
    end
  end
end
