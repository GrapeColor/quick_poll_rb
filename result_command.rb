# frozen_string_literal: true

class QuickPoll
  # COLOR_POLL     = 0x3b88c3
  # COLOR_EXPOLL   = COLOR_POLL.next
  # COLOR_FREEPOLL = COLOR_EXPOLL.next
  COLOR_RESULT = 0xdd2e44

  private

  def set_result_command
    @bot.command(:sumpoll) do |event, message_id|
      next await_cancel(event.message, show_help(event)) unless message_id
      await_cancel(event.message, show_result(event, message_id))
    end
  end

  def show_result(event, message_id)
    channel = event.channel
    unless message = channel.message(message_id.to_i)
      return send_error(channel, "指定された投票が見つかりません")
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
      mention = reaction_mention(reaction)
      Discordrb::Webhooks::EmbedField.new(
        name: "#{mention}** #{options[mention]}**\u200C",
        value: opt_value(counts[i], total, max, inline),
        inline: inline
      )
    end
  end

  def reaction_mention(reaction)
    reaction.id ? @bot.emoji(reaction.id).mention : reaction.name
  end

  def opt_value(count, total, max, inline)
    persentage = (100.0 * count / total).round(1)
    value = "#{count}票 (#{persentage}%)"
    value = "**#{value}** 🏆" if count == max
    "#{value}　　\u200C"
  end
end
