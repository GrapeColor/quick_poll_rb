require 'dotenv/load'
require './quick_poll'

quick_poll = QuickPoll.new(ENV['QUICK_POLL_TOKEN'])
quick_poll.run
