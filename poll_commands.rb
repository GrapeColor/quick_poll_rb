# frozen_string_literal: true

require 'unicode/emoji'

class String
  def emoji?
    return true if self =~ /^<:.+:\d+>$/
    !!(self =~ /^#{Unicode::Emoji::REGEX_WELL_FORMED_INCLUDE_TEXT}$/)
  end
end

class QuickPoll
  MAX_OPTIONS = 20
  DEFAULT_EMOJIS = [
    "🇦", "🇧", "🇨", "🇩", "🇪",
    "🇫", "🇬", "🇭", "🇮", "🇯",
    "🇰", "🇱", "🇲", "🇳", "🇴",
    "🇵", "🇶", "🇷", "🇸", "🇹",
  ].freeze

  COLOR_POLL     = 0x3b88c3
  COLOR_EXPOLL   = COLOR_POLL.next
  COLOR_FREEPOLL = COLOR_EXPOLL.next
  COLOR_ERROR    = 0xffcc4d

  SIMPLE_POLL = 324631108731928587

  private

  def set_poll_commands
    poll_proc = proc do |event, arg|
      next await_cancel(event.message, show_help(event)) unless arg
      create_poll(event)
    end

    @bot.command(:poll) do |event, arg|
      next if event.server&.member(SIMPLE_POLL, false)
      poll_proc.call(event, arg)
    end

    @bot.command(:expoll) do |event, arg|
      channel = event.channel
      message = event.message

      next await_cancel(message, send_error(channel, "DMでは /expoll が利用できません")) if channel.private?

      unless event.server&.bot.permission?(:manage_messages, channel)
        await_cancel(
          message,
          send_error(
            channel,
            "/expoll が利用できません",
            "`/expoll` コマンドの実行にはBOTに **メッセージの管理** 権限が必要です"
          )
        )
        next
      end

      poll_proc.call(event, arg)
    end

    @bot.command(:freepoll, &poll_proc)

    @bot.command(:numpoll, &poll_proc)

    @bot.reaction_add { |event| exclusive_reaction(event) }
  end

  def create_poll(event)
    channel = event.channel
    message = event.message
    poll = event.send("⌛ 投票生成中...")
    args = parse_content(event.content)
    command, query = args.shift(2)

    begin
      options = parse_args(command, args)
    rescue TooFewOptions
      poll.delete
      return await_cancel(message, send_error(channel, "選択肢が1個を下回っています"))
    rescue TooManyOptions
      poll.delete
      return await_cancel(message, send_error(channel, "選択肢が20個を超えています"))
    rescue DuplicateEmojis
      poll.delete
      return await_cancel(message, send_error(channel, "絵文字が重複しています"))
    end

    unless check_external_emoji(channel, options.keys)
      poll.delete
      await_cancel(
        message,
        send_error(
          channel,
          "外部の絵文字が利用できません",
          "投票に外部の絵文字を使用したい場合、BOTに **外部の絵文字の使用** 権限が必要です"
        )
      )
      return
    end

    message.attachments
    image_url = get_with_image(message.attachments)

    embed = case command
      when "/poll", "/numpoll"
        poll_embed(
          poll, COLOR_POLL, query, event.author, image_url,
          "選択肢にリアクションで投票できます",
          options
        )
      when "/expoll"
        poll_embed(
          poll, COLOR_EXPOLL, query, event.author, image_url,
          "選択肢にリアクションで1人1つ投票できます",
          options
        )
      when "/freepoll"
        poll_embed(
          poll, COLOR_FREEPOLL, query, event.author, image_url,
          "任意のリアクションで自由に投票できます"
        )
      else
        return
      end

    poll.edit("", embed)
    add_reactions(poll, options.keys)
    await_cancel(message, poll)
  end

  def parse_content(content)
    args = []
    arg = quote = ""
    escape = false

    add_arg = -> do
      args << arg.strip if arg != ""
      arg = ""
    end

    content.chars.each do |char|
      if char =~ /["'”]/ && !escape && (quote == "" || quote == char)
        quote = quote == "" ? char : ""
        next add_arg.call
      end

      next if escape = char == "\\" && !escape

      if char == " " && quote == "" || char == "\n"
        quote = ""
        next add_arg.call
      end

      arg += char
    end

    add_arg.call
    args
  end

  class TooFewOptions < StandardError; end
  class TooManyOptions < StandardError; end
  class DuplicateEmojis < StandardError; end

  def parse_args(command, args)
    case command
    when "/freepoll"
      return {}
    when "/numpoll"
      num = args[0].tr("０-９", "0-9").to_i
      raise TooFewOptions if num < 1
      raise TooManyOptions if num > MAX_OPTIONS
      return DEFAULT_EMOJIS[0...num].zip([]).to_h
    end

    raise TooManyOptions if args.size > MAX_OPTIONS * 2
    return { "⭕" => nil, "❌" => nil } if args.empty?

    if args.map(&:emoji?).all?
      raise TooManyOptions if args.size > MAX_OPTIONS
      raise DuplicateEmojis if args.size > args.uniq.size
      return args.zip([]).to_h
    end

    emojis, opts = args.partition.with_index { |_, i| i.even? }

    if args.size.even? && emojis.map(&:emoji?).all?
      raise TooManyOptions if emojis.size > MAX_OPTIONS
      raise DuplicateEmojis if emojis.size > emojis.uniq.size
      return emojis.zip(opts).to_h
    end

    raise TooManyOptions if args.size > MAX_OPTIONS
    return DEFAULT_EMOJIS[0...args.size].zip(args).to_h
  end

  def poll_embed(message, color, query, author, image_url, footer, options = {})
    title = "📊 #{query}\u200c"
    description = options.map do |emoji, opt|
      "\u200B#{emoji} #{opt}\u200C" if opt
    end.compact.join("\n")
    description += "\n\n投票結果は `/sumpoll #{message.id}` で集計"
    author = Discordrb::Webhooks::EmbedAuthor.new(
      icon_url: author.avatar_url,
      name: author.respond_to?(:display_name) ? author.display_name : author.distinct
    )
    image = Discordrb::Webhooks::EmbedImage.new(url: image_url) if image_url
    footer = Discordrb::Webhooks::EmbedFooter.new(text: footer)

    Discordrb::Webhooks::Embed.new(
      title: title, description: description, color: color, author: author, footer: footer, image: image
    )
  end

  def send_error(channel, title, description = "")
    channel.send_embed do |embed|
      embed.color = COLOR_ERROR
      embed.title = "⚠️ #{title}"
      embed.description = description
    end
  end

  def get_with_image(attachments)
    attachments.find do |attachment|
      next if attachment.height.nil?
      attachment.filename =~ /\.(png|jpg|jpeg|gif|webp)$/
    end&.url
  end

  def add_reactions(message, emojis)
    emojis.each do |emoji|
      message.react(emoji =~ /<a?:(.+:\d+)>/ ? $1 : emoji)
    end
  end

  def await_cancel(message, poll)
    message.react("↩️")

    @bot.add_await!(Discordrb::Events::ReactionAddEvent, { timeout: 60, emoji: "↩️" }) do |event|
      next unless event.message == message && event.user == message.user
      poll.delete rescue nil
      true
    end

    message.delete_own_reaction("↩️") rescue nil
    nil
  end

  def check_external_emoji(channel, emojis)
    server = channel.server
    return true if channel.private? || server.bot.permission?(:use_external_emoji, channel)

    !emojis.find do |emoji|
      next if emoji !~ /<:.+:(\d+)>/
      !server.emojis[$1.to_i]
    end
  end

  def exclusive_reaction(event)
    message = event.message
    poll = message.embeds[0]
    return unless message.from_bot?
    return if poll.color != COLOR_EXPOLL

    message.reactions.each do |reaction|
      next if event.emoji.to_reaction == reaction.to_s
      message.delete_reaction(event.user, reaction.to_s)
    end
  end
end
