# frozen_string_literal: true

require 'dotenv/load'
require_relative './quick_poll/bot'

quick_poll = QuickPoll::Bot.new(
  token: ENV['QUICK_POLL_TOKEN'], shard_id: ENV['QUICK_POLL_SHARD_ID'].to_i, num_shards: ENV['QUICK_POLL_NUM_SHARDS'].to_i
)
quick_poll.run
