# frozen_string_literal: true

module QuickPoll
  class Canceler
    TIMEOUT = 60

    def self.events(bot)
      @@cancelers ||= {}

      bot.heartbeat { @@cancelers.values.select(&:timeout?).each(&:remove) }

      bot.reaction_add({ emoji: "↩️" }) do |event|
        next unless canceler = @@cancelers[event.message.id]

        canceler.cancel if event.user == canceler.message.user
      end
    end

    def initialize(message, response)
      message.react("↩️")
    rescue
      return nil
    else
      @message = message
      @response = response
      @timeout = Time.now + TIMEOUT

      @@cancelers[@message.id] = self
    end

    attr_reader :message

    def cancel
      @response.delete
    rescue
      nil
    ensure
      remove
    end

    def timeout?
      Time.now >= @timeout
    end

    def remove
      @@cancelers.delete(@message.id)
      @message.delete_own_reaction("↩️")
    rescue
      nil
    else
      nil
    end
  end
end
