# frozen_string_literal: true

require 'bundler/setup'
require 'discordrb'

module QuickPoll
  HELP_URL = 'https://gist.github.com/GrapeColor/2c2539bb02a7b6033a21af3befe8c1d2'
  SUPPORT_URL = ENV['SUPPORT_URL']
  DONATION_URL = 'https://ofuse.me/users/grapecolor'

  PERMISSION_BITS = 388160
  NEED_PERMISSIONS = Discordrb::Permissions::FLAGS.select do |bit, _|
    PERMISSION_BITS & 2 ** bit > 0
  end.values.freeze

  COMMANDS = %w(poll freepoll numpoll sumpoll csvpoll).freeze

  COLOR_HELP   = 0xff922f
  COLOR_WAIT   = 0x9867c6
  COLOR_POLL   = 0x3b88c3
  COLOR_EXPOLL = 0x3b88c4
  COLOR_RESULT = 0xdd2e44
  COLOR_ERROR  = 0xffcc4d

  class Bot
    def initialize(token: , shard_id: nil, num_shards: nil, log_mode: :normal)
      @bot = Discordrb::Bot.new(
        token: token, ignore_bots: true, shard_id: shard_id, num_shards: num_shards, log_mode: log_mode
      )

      @ready_count = 0
      @bot.ready do
        @ready_count += 1
        @bot.mode = :debug if @ready_count > 20

        @bot.update_status(:dnd, "再接続しました (#{@ready_count})", nil)
        @hb_count = 0
      end if @bot.shard_key[0] == 0

      @bot.heartbeat do
        if @hb_count.even?
          @bot.update_status(:online, "/poll | ex/poll", nil)
        else
          @bot.update_status(:online, "#{@bot.servers.size} サーバー / #{@bot.shard_key[1]} shards", nil)
        end
        @hb_count += 1
      end if @bot.shard_key[0] == 0

      Response.events(@bot)
      Canceler.events(@bot)
      Poll.events(@bot)
      Admin.events(@bot) if @bot.shard_key[0] == 0
    end

    def run(background = false)
      @bot.run(background)
    end
  end
end

require_relative './canceler'
require_relative './base'
require_relative './response'
require_relative './poll'
require_relative './result'
require_relative './export'
require_relative './help'
require_relative './admin'
