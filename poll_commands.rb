# frozen_string_literal: true

class QuickPoll
  COMMANDS = %w(poll freepoll numpoll sumpoll).freeze
  COLOR_ERROR = 0xffcc4d

  private

  def set_poll_commands
    @command_count = Hash.new(0)
    @bot.message { |event| parse_message(event) }

    @last_reactions = Hash.new { |h, k| h[k] = {} } 
    @bot.reaction_add { |event| exclusive_reaction(event) }
    @bot.reaction_remove do |event|
      message = event.message
      user = event.user
      reaction = @last_reactions[message.id][user.id]
      @last_reactions[message.id][user.id] = "" if event.emoji.to_reaction == reaction
    end
  end

  def parse_message(event)
    content = event.content
    server = event.server
    prefix = @server_prefixes[server&.id]
    match_prefix = content.match(/^(ex)?#{Regexp.escape(prefix)}/)
    return unless match_prefix

    ex = !!match_prefix[1]
    args = parse_content(content)
    args[0].delete_prefix!("#{"ex" if ex}#{prefix}")
    return unless COMMANDS.include?(args[0])

    @command_count[server.id] += 1
    exec_command(event, prefix, ex, args)
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
      if (char == '"' || char == "'" || char == '”') && (quote == "" || quote == char) && !escape
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

  def exec_command(event, prefix, ex, args)
    if args.size <= 1
      await_cancel(event.message, show_help(event, prefix)) 
      return
    end

    if args[0] == "sumpoll"
      exec_sumpoll(event, prefix, args)
      return
    end

    return unless exec_expoll(event, prefix) if ex
    create_poll(event, prefix, ex, args)
  rescue => e
    trace_error(event, e)
  end

  def exec_expoll(event, prefix)
    channel = event.channel
    message = event.message

    if channel.private?
      send_error(channel, message, "DM・グループDM内では 'ex#{prefix}' プレフィックスが利用できません")
      return false
    end

    unless event.server&.bot.permission?(:manage_messages, channel)
      send_error(
        channel, message, "'ex#{prefix}' プレフィックスが利用できません",
        "`ex#{prefix}` プレフィックスコマンドの実行にはBOTに **メッセージの管理** 権限が必要です"
      )
      return false
    end

    true
  end

  def exec_sumpoll(event, prefix, args)
    result = show_result(event, args[1])
    await_cancel(event.message, result)
  rescue => e
    trace_error(event, e)
  end

  def send_error(channel, message, title, description = "")
    poll = channel.send_embed do |embed|
      embed.color = COLOR_ERROR
      embed.title = "⚠️ #{title}"
      embed.description = description + "\n[質問・不具合報告](https://discord.gg/STzZ6GK)"
    end
    await_cancel(message, poll)
  end

  def await_cancel(message, poll)
    message.react("↩️") rescue return

    @bot.add_await!(Discordrb::Events::ReactionAddEvent, { timeout: 60, emoji: "↩️" }) do |event|
      next unless event.message == message && event.user == message.user
      poll.delete rescue nil
      true
    end

    message.delete_own_reaction("↩️") rescue nil
    nil
  end

  def exclusive_reaction(event)
    message = event.message
    poll_embed = message.embeds[0]
    return unless message.from_bot?
    return if poll_embed.color != COLOR_EXPOLL

    user = event.user
    emoji = event.emoji
    reacted = @last_reactions[message.id][user.id]
    @last_reactions[message.id][user.id] = emoji.to_reaction

    if reacted
      message.delete_reaction(user, reacted) rescue nil if reacted != ""
    else
      message.reactions.each do |reaction|
        next if @last_reactions[message.id][user.id] == reaction.to_s
        message.delete_reaction(user, reaction.to_s) rescue nil
      end
    end
  end
end
