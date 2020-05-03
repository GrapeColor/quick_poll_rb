# frozen_string_literal: true

class QuickPoll
  SIMPLE_POLL = 324631108731928587
  COLOR_ERROR = 0xffcc4d

  private

  def set_poll_commands
    @bot.command(:poll) do |event, arg|
      if member = event.server&.member(SIMPLE_POLL, false)
        next if member.permission?(:read_messages, event.channel) && member.status != :offline
      end

      poll_proc.call(event, arg)
    end

    @bot.command(:expoll) do |event, arg|
      channel = event.channel
      message = event.message

      next send_error(channel, message, "DMでは /expoll が利用できません") if channel.private?

      unless event.server&.bot.permission?(:manage_messages, channel)
        send_error(
          channel, message, "/expoll が利用できません",
          "`/expoll` コマンドの実行にはBOTに **メッセージの管理** 権限が必要です"
        )
        next
      end

      poll_proc.call(event, arg)
    end

    @bot.command(:freepoll, &poll_proc)

    @bot.command(:numpoll, &poll_proc)

    @bot.command(:sumpoll) do |event, message_id|
      message = event.message
      next await_cancel(message, show_help(event)) unless message_id

      begin
        result = show_result(event, message_id)
      rescue => e
        trace_error(event, e)
        next
      end

      await_cancel(message, result)
    end

    @bot.reaction_add { |event| exclusive_reaction(event) }
  end

  def poll_proc
    proc do |event, arg|
      next await_cancel(event.message, show_help(event)) unless arg
      create_poll(event)
    rescue => e
      next trace_error(event, e)
    end
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
    message.react("↩️")

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
    poll = message.embeds[0]
    return unless message.from_bot?
    return if poll.color != COLOR_EXPOLL

    message.reactions.each do |reaction|
      next if event.emoji.to_reaction == reaction.to_s
      message.delete_reaction(event.user, reaction.to_s)
    end
  end
end
