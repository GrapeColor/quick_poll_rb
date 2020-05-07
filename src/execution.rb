# frozen_string_literal: true

require 'dotenv/load'
require_relative './quick_poll/bot'

class Discordrb::Logger
  private
  alias_method :_write, :write

  def write(message, mode)
    return if message =~ /(RL bucket depletion detected|Locking RL mutex)/
    _write(message, mode)
  end
end

quick_poll = QuickPoll::Bot.new(token: ENV['QUICK_POLL_TOKEN'], log_mode: :debug)
quick_poll.run
