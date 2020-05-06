# frozen_string_literal: true

module QuickPoll
  class Result
    include Base

    def initialize(event, message_id)
      channel = event.channel
      message = channel.message(message_id.to_i)
      result = send_waiter(channel, "投票集計中...") rescue return
      poll_embed = message.embeds[0] if message

      unless message&.from_bot? && (COLOR_POLL..COLOR_FREEPOLL).cover?(poll_embed.color)
        result.delete
        send_error(channel, event.message, "指定された投票が見つかりません")
        return
      end

      free = message.my_reactions == []
      options = poll_embed.description.scan(/\u200B(.+?) (.+?)\u200C/).to_h
      reactions = free ? message.reactions : message.my_reactions
      if reactions == []
        result.delete
        send_error(channel, event.message, "まだ何も投票されていません")
        return
      end

      embed = Discordrb::Webhooks::Embed.new
      embed.color = COLOR_RESULT
      embed.title = poll_embed.title
      embed.author = Discordrb::Webhooks::EmbedAuthor.new(
        icon_url: poll_embed.author.icon_url, name: poll_embed.author.name
      )
      embed.image = Discordrb::Webhooks::EmbedImage.new(
        url: poll_embed.image&.url
      )
      embed.fields = result_fields(event.bot, reactions, options, free)

      Canceler.new(event.message, result.edit("", embed))
    end

    private

    def result_fields(bot, reactions, options, free)
      counts = reactions.map(&:count)
      counts = counts.map(&:pred) unless free
      total = [counts.sum, 1].max
      max = [counts.max, 1].max

      inline = reactions.size > 7
      reactions.map.with_index do |reaction, i|
        mention = reaction.id ? bot.emoji(reaction.id).mention : reaction.name
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
end
