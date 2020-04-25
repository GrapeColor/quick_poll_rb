class QuickPoll
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

  def poll_commands
    poll_proc = proc do |event, arg|
      next await_cancel(event.message, show_help(event)) unless arg
      create_poll(event)
    end

    @bot.command(:poll) do |event, arg|
      next if event.server&.member(SIMPLE_POLL, false)
      poll_proc.call(event, arg)
    end

    @bot.command(:expoll, &poll_proc)
    @bot.command(:freepoll, &poll_proc)

    @bot.reaction_add do |event|
      exclusive_vote(event)
    end
  end

  def create_poll(event)
    channel = event.channel
    message = event.message
    poll = event.send("⌛ 投票生成中...")
    args = parse_content(event.content)
    command, query = args.shift(2)

    begin
      if command != "/freepoll"
        options = parse_args(args)
        add_reactions(poll, options.keys)
      end
    rescue TooManyOptions
      poll.delete
      return await_cancel(message, send_error(channel, "選択肢が20個を超えています"))
    rescue DuplicateEmojis
      poll.delete
      return await_cancel(message, send_error(channel, "絵文字が重複しています"))
    end

    embed = case command
      when "/poll"
        poll_embed(
          poll, COLOR_POLL, query, event.author,
          "選択肢にリアクションで投票できます",
          options
        )
      when "/expoll"
        poll_embed(
          poll, COLOR_EXPOLL, query, event.author,
          "選択肢にリアクションで1人1つ投票できます",
          options
        )
      when "/freepoll"
        poll_embed(
          poll, COLOR_FREEPOLL, query, event.author,
          "任意のリアクションで自由に投票できます"
        )
      else
        return
      end

    await_cancel(message, poll.edit("", embed))
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

  def add_reactions(message, emojis)
    Thread.fork(message, emojis) do |message, emojis|
      emojis.each do |emoji|
        message.react(emoji =~ /<a?:(.+:\d+)>/ ? $1 : emoji)
      end
    end
  end

  def poll_embed(message, color, query, author, footer, options = {})
    title = "📊 #{query}\u200c"
    description = options.map do |emoji, opt|
      "\u200B#{emoji} #{opt}\u200C" if opt
    end.compact.join("\n")
    description += "\n\n投票は `/sumpoll #{message.id}` で集計"
    author = Discordrb::Webhooks::EmbedAuthor.new(
      icon_url: author.avatar_url,
      name: author.respond_to?(:display_name) ? author.display_name : author.distinct
    )
    footer = Discordrb::Webhooks::EmbedFooter.new(text: footer)

    Discordrb::Webhooks::Embed.new(
      title: title, description: description, color: color, author: author, footer: footer
    )
  end

  def send_error(channel, title, description = "")
    channel.send_embed do |embed|
      embed.color = COLOR_ERROR
      embed.title = "⚠️ #{title}"
      embed.description = description
    end
  end

  def await_cancel(message, poll)
    message.react("↩️")

    attrs = { timeout: 60, emoji: "↩️" }
    @bot.add_await!(Discordrb::Events::ReactionAddEvent, attrs) do |event|
      next unless event.message == message && event.user == message.user
      poll.delete
      true
    end

    begin
      message.delete_own_reaction("↩️")
    rescue; nil; end
    nil
  end

  def exclusive_vote(event)
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
