class QuickPoll
  DEFAULT_EMOJIS = [
    "🇦", "🇧", "🇨", "🇩", "🇪",
    "🇫", "🇬", "🇭", "🇮", "🇯",
    "🇰", "🇱", "🇲", "🇳", "🇴",
    "🇵", "🇶", "🇷", "🇸", "🇹",
  ].freeze

  COLOR_POLL     = 0x3b88c3
  COLOR_EXPOLL   = 0x3b88c4
  COLOR_FREEPOLL = 0x3b88c5
  COLOR_RESULT   = 0xdd2e44
  COLOR_ERROR    = 0xffcc4d

  private
  def set_commands
    poll_proc = proc do |event, arg|
      next show_help(event) unless arg
      create_poll(event)
    end

    @bot.command(:poll, &poll_proc)
    @bot.command(:expoll, &poll_proc)
    @bot.command(:freepoll, &poll_proc)
    @bot.command(:sumpoll) do |event, message_id|
      next show_help(event) unless message_id
      show_result(event, message_id)
    end

    @bot.reaction_add do |event|
      exclusive_vote(event)
    end
  end

  def create_poll(event)
    channel = event.channel
    poll = event.send("⌛ 投票生成中...")
    args = parse_content(event.content)
    command, query = args.shift(2)

    begin
      if command != "/freepoll"
        options = parse_args(args)
        add_reactions(poll, options.keys)
      end
    rescue TooManyOptions
      send_error(channel, "選択肢が20個を超えています")
      return
    rescue DuplicateEmojis
      send_error(channel, "絵文字が重複しています")
      return
    end

    embed = case command
            when "/poll"
              poll_embed(
                poll, COLOR_POLL, query,
                "選択肢をリアクションで投票できます",
                options
              )
            when "/expoll"
              poll_embed(
                poll, COLOR_EXPOLL, query,
                "選択肢をリアクションで1人1つ投票できます",
                options
              )
            when "/freepoll"
              poll_embed(
                poll, COLOR_FREEPOLL, query,
                "リアクションで自由に投票できます"
              )
            else
              return
            end

    poll.edit("", embed)
    await_cancel(event.message, poll)
    nil
  end

  def show_result(event)
    message = event.message
    return unless message.from_bot?

    embed = message.embeds[0]
    if embed.color == COLOR_POLL || embed.color == COLOR_EXPOLL
      args = parse_content(embed.description)
      
    end

    nil
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
        add_arg.call
        next
      end

      next if escape = char == "\\" && !escape

      if char == " " && quote == "" || char == "\n"
        quote = ""
        add_arg.call
        next
      end

      arg += char
    end

    add_arg.call
    args
  end

  class TooManyOptions < StandardError; end
  class DuplicateEmojis < StandardError; end

  def parse_args(args)
    raise TooManyOptions if args.size > 40
    return { "⭕" => nil, "❌" => nil } if args.empty?

    if args.map(&:emoji?).all?
      raise TooManyOptions if args.size > 20
      raise DuplicateEmojis if args.size > args.uniq.size
      return args.zip([]).to_h
    end

    emojis, opts = args.partition.with_index { |_, i| i.even? }

    if args.size.even? && emojis.map(&:emoji?).all?
      raise TooManyOptions if emojis.size > 20
      raise DuplicateEmojis if emojis.size > emojis.uniq.size
      return emojis.zip(opts).to_h
    end

    raise TooManyOptions if args.size > 20
    return DEFAULT_EMOJIS[0...args.size].zip(args).to_h
  end

  def send_error(channel, title, description = "")
    channel.send_embed do |embed|
      embed.color = COLOR_ERROR
      embed.title = "⚠️ #{title}"
      embed.description = description
    end
  end

  def add_reactions(message, emojis)
    Thread.fork(message, emojis) do |message, emojis|
      emojis.each do |emoji|
        message.react(emoji =~ /<:(.+:\d+)>/ ? $1 : emoji)
      end
    end
  end

  def poll_embed(message, color, query, footer, options = {})
    title = "📊 #{query}\u200c"
    description = options.map do |emoji, opt|
      "#{emoji} #{opt}" if opt
    end.compact.join("\n")
    description += "\n\n集計は `/sumpoll #{message.id}` を実行"
    footer = Discordrb::Webhooks::EmbedFooter.new(text: footer)

    Discordrb::Webhooks::Embed.new(
      title: title, description: description, color: color, footer: footer
    )
  end

  def await_cancel(message, poll)
    message.react("↩️")

    attrs = { timeout: 60, emoji: "↩️" }
    @bot.add_await!(Discordrb::Events::ReactionAddEvent, attrs) do |event|
      next unless event.message == message && event.user == message.user
      poll.delete
      true
    end

    message.delete_own_reaction("↩️")
  end
end
