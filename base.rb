# frozen_string_literal: true

module QuickPoll
  module Base
    private

    def send_waiter(channel, msg)
      channel.send_embed do |embed|
        embed.color = COLOR_WAIT
        embed.title = "⌛ #{msg}"
      end
    end

    def send_error(channel, message, title, description = "")
      error = channel.send_embed do |embed|
        embed.color = COLOR_ERROR
        embed.title = "⚠️ #{title}"
        embed.description = description + "\n[質問・不具合報告](#{SUPPORT_URL})"
      end

      Canceler.new(message, error)
    end
  end
end
