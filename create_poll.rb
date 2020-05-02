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

  COLOR_WAIT     = 0x9867c6
  COLOR_POLL     = 0x3b88c3
  COLOR_EXPOLL   = COLOR_POLL.next
  COLOR_FREEPOLL = COLOR_EXPOLL.next
  COLOR_RESULT   = 0xdd2e44

  private

  def create_poll(event)
    channel = event.channel
    message = event.message
    poll = send_waiter(channel) rescue return

    command, query, options, image_url = parse_command(channel, message, poll)

    color, footer = case command
      when "/poll", "/numpoll"
        [COLOR_POLL, "選択肢にリアクションで投票できます"]
      when "/expoll"
        [COLOR_EXPOLL, "選択肢にリアクションで1人1つ投票できます"]
      when "/freepoll"
        [COLOR_FREEPOLL, "任意のリアクションで自由に投票できます"]
      else
        return
      end

    poll.edit("", poll_embed(poll, color, event.author, query, options, image_url, footer))
    return unless add_reactions(message, poll, options.keys)
    await_cancel(message, poll)
  end

  def send_waiter(channel)
    channel.send_embed do |embed|
      embed.color = COLOR_WAIT
      embed.title = "⌛ 投票生成中..."
    end
  end

  def parse_command(channel, message, poll)
    args = parse_content(message.content)
    command, query = args.shift(2)

    begin
      options = parse_args(command, args)
    rescue TooFewOptions
      poll.delete
      return send_error(channel, message, "選択肢が1個を下回っています")
    rescue TooManyOptions
      poll.delete
      return send_error(channel, message, "選択肢が20個を超えています")
    rescue DuplicateEmojis
      poll.delete
      return send_error(channel, message, "絵文字が重複しています")
    end

    unless check_external_emoji(channel, options.keys)
      poll.delete
      send_error(
        channel, message, "外部の絵文字が利用できません",
        "投票に外部の絵文字を使用したい場合、BOTに **外部の絵文字の使用** 権限が必要です"
      )
      return
    end

    message.attachments
    image_url = get_with_image(message.attachments)

    [command, query, options, image_url]
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

  def poll_embed(message, color, author, query, options, image_url, footer)
    embed = Discordrb::Webhooks::Embed.new

    embed.color = color
    embed.title = "📊 #{query}\u200c"

    embed.description = options.map do |emoji, opt|
      "\u200B#{emoji} #{opt}\u200C" if opt
    end.compact.join("\n")
    embed.description += "\n\n投票結果は `/sumpoll #{message.id}` で集計"

    embed.author = Discordrb::Webhooks::EmbedAuthor.new(
      icon_url: author.avatar_url,
      name: author.respond_to?(:display_name) ? author.display_name : author.distinct
    )
    embed.image = Discordrb::Webhooks::EmbedImage.new(url: image_url)
    embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: footer)

    embed
  end

  def get_with_image(attachments)
    attachments.find do |attachment|
      next if attachment.height.nil?
      attachment.filename =~ /\.(png|jpg|jpeg|gif|webp)$/
    end&.url
  end

  def add_reactions(message, poll, emojis)
    emojis.each { |emoji| poll.react(emoji =~ /<a?:(.+:\d+)>/ ? $1 : emoji) }
  rescue
    poll.delete
    send_error(
      channel, message, "投票を作成できません",
      "投票を作成するためには、BOTに **メッセージ履歴を読む** と **リアクションの追加** 権限が必要です"
    )
  end

  def check_external_emoji(channel, emojis)
    server = channel.server
    return true if channel.private? || server.bot.permission?(:use_external_emoji, channel)

    !emojis.find do |emoji|
      next if emoji !~ /<:.+:(\d+)>/
      !server.emojis[$1.to_i]
    end
  end

  def show_result(event, message_id)
    channel = event.channel
    unless message = channel.message(message_id.to_i)
      return send_error(channel, event.message, "指定された投票が見つかりません")
    end

    poll = message.embeds[0]
    return unless message.from_bot?
    return unless (COLOR_POLL..COLOR_FREEPOLL).cover?(poll.color)

    free = poll.color == COLOR_FREEPOLL
    options = poll.description.scan(/\u200B(.+?) (.+?)\u200C/).to_h
    reactions = free ? message.reactions : message.my_reactions

    event.send_embed do |embed|
      embed.color = COLOR_RESULT
      embed.title = poll.title
      embed.author = Discordrb::Webhooks::EmbedAuthor.new(
        icon_url: poll.author.icon_url, name: poll.author.name
      )
      embed.image = Discordrb::Webhooks::EmbedImage.new(
        url: poll.image&.url
      )
      embed.fields = result_fields(reactions, options, free)
    end
  end

  def result_fields(reactions, options, free)
    counts = reactions.map(&:count)
    counts = counts.map(&:pred) unless free
    total = [counts.sum, 1].max
    max = [counts.max, 1].max

    inline = reactions.size > 7
    reactions.map.with_index do |reaction, i|
      mention = reaction.id ? @bot.emoji(reaction.id).mention : reaction.name
      Discordrb::Webhooks::EmbedField.new(
        name: "#{mention}** #{options[mention]}**\u200C",
        value: opt_value(counts[i], total, max, inline),
        inline: inline
      )
    end
  end

  def opt_value(count, total, max, inline)
    persentage = (100.0 * count / total).round(1)
    value = "#{count}票 (#{persentage}%)"
    value = "**#{value}** 🏆" if count == max
    "#{value}　　\u200C"
  end
end
