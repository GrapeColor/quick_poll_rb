# frozen_string_literal: true

module QuickPoll
  module Base
    private

    def send_waiter(msg)
      @channel.send_embed do |embed|
        embed.color = COLOR_WAIT
        embed.title = "⌛ #{msg}"
      end
    rescue
      raise ImpossibleSend
    end

    def send_error(title, description = "")
      @channel.send_embed do |embed|
        embed.color = COLOR_ERROR
        embed.title = "⚠️ #{title}"
        embed.description = description + "\n[ご質問・不具合報告](#{SUPPORT_URL})"
      end
    end
  end
end
