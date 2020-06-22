# frozen_string_literal: true

module QuickPoll
  class Result
    include Base

    def initialize(event, message_id)
      receive_args(event, message_id)

      @response = send_waiter("投票集計中...")

      return unless is_poll? && parse_poll

      embed = Discordrb::Webhooks::Embed.new
      embed.color = COLOR_RESULT
      embed.title = @poll_embed.title
      embed.author = { icon_url: @poll_embed.author.icon_url, name: @poll_embed.author.name }
      embed.image = { url: @poll_embed.image&.url }
      embed.fields = result_fields

      @response.edit("", embed)
    end

    attr_reader :response

    private

    def receive_args(event, message_id)
      @bot = event.bot
      @channel = event.channel
      @message = event.message
      @poll = @channel.message(message_id.to_i)
      @poll_embed = @poll.embeds[0] if @poll
    end

    def is_poll?
      unless @poll&.from_bot? && (COLOR_POLL..COLOR_EXPOLL) === @poll_embed&.color
        @response.delete
        @response = send_error("指定された投票が見つかりません")
        return false
      end

      true
    end

    def parse_poll
      @free = @poll.my_reactions == []
      @options = @poll_embed.description.scan(/^(.+?) (.+?)\u200C$/).to_h
      @reactions = @free ? @poll.reactions : @poll.my_reactions

      if @reactions == []
        @response.delete
        @response = send_error("まだ何も投票されていません")
        return false
      end

      @counts = @reactions.map(&:count)
      @counts = @counts.map(&:pred) unless @free
      @total = [@counts.sum, 1].max
      @max = [@counts.max, 1].max

      true
    end

    def result_fields
      inline = @reactions.size > 7
      @reactions.map.with_index do |reaction, i|
        mention = emoji_mention(reaction)
        {
          name: "#{mention}** #{@options[mention]}**\u200C",
          value: opt_value(@counts[i]),
          inline: inline
        }
      end
    end

    def emoji_mention(reaction)
      reaction.id ? @bot.emoji(reaction.id).mention : reaction.name
    end

    def opt_value(count)
      persentage = (100.0 * count / @total).round(1)
      value = "#{count}票 (#{persentage}%)"
      value = "**#{value}** 🏆" if count == @max
      "#{value}　　\u200C"
    end
  end
end
