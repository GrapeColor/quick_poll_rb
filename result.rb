# frozen_string_literal: true

module QuickPoll
  class Result
    include Base

    def initialize(event, message_id)
      @bot = event.bot
      @channel = event.channel
      @message = event.message
      @poll = @channel.message(message_id.to_i)
      @poll_embed = @poll.embeds[0] if @poll

      @response = send_waiter("投票集計中...")

      unless @poll&.from_bot? && (COLOR_POLL..COLOR_FREEPOLL).cover?(@poll_embed.color)
        @response.delete
        @response = send_error("指定された投票が見つかりません")
        return
      end

      return unless parse_poll

      embed = Discordrb::Webhooks::Embed.new
      embed.color = COLOR_RESULT
      embed.title = @poll_embed.title
      embed.author = { icon_url: @poll_embed.author.icon_url, name: @poll_embed.author.name }
      embed.image = { url: @poll_embed.image&.url }
      embed.fields = result_fields

      @response.edit("", embed)
    end

    def delete
      @response.delete
    end

    private

    def parse_poll
      @free = @poll.my_reactions == []
      @options = @poll_embed.description.scan(/\u200B(.+?) (.+?)\u200C/).to_h
      @reactions = @free ? @poll.reactions : @poll.my_reactions

      if @reactions == []
        @response.delete
        @response = send_error("まだ何も投票されていません")
        return false
      end

      true
    end

    def result_fields
      counts = @reactions.map(&:count)
      counts = counts.map(&:pred) unless @free
      total = [counts.sum, 1].max
      max = [counts.max, 1].max

      inline = @reactions.size > 7
      @reactions.map.with_index do |reaction, i|
        mention = reaction.id ? @bot.emoji(reaction.id).mention : reaction.name
        Discordrb::Webhooks::EmbedField.new(
          name: "#{mention}** #{@options[mention]}**\u200C",
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
