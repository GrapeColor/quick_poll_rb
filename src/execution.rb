# frozen_string_literal: true

require 'dotenv/load'
require_relative './quick_poll/bot'

quick_poll = QuickPoll::Bot.new(ENV['QUICK_POLL_TOKEN'])
quick_poll.run
