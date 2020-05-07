# frozen_string_literal: true

require 'bundler/setup'
require 'discordrb'

require_relative './canceler'
require_relative './base'
require_relative './response'
require_relative './poll'
require_relative './result'
require_relative './help'
require_relative './admin'

module QuickPoll
  SUPPORT_URL = "https://discord.gg/STzZ6GK"

  PERMISSION_BITS = 355392
  NEED_PERMISSIONS = Discordrb::Permissions::FLAGS.select do |bit, _|
    PERMISSION_BITS & 2 ** bit > 0
  end.values.freeze

  COMMANDS = %w(poll freepoll numpoll sumpoll).freeze

  COLOR_HELP     = 0xff922f
  COLOR_WAIT     = 0x9867c6
  COLOR_POLL     = 0x3b88c3
  COLOR_EXPOLL   = COLOR_POLL.next
  COLOR_FREEPOLL = COLOR_EXPOLL.next
  COLOR_RESULT   = 0xdd2e44
  COLOR_ERROR    = 0xffcc4d

  class Bot
    def initialize(token: , log_mode: :normal)
      @bot = Discordrb::Bot.new(token: token, ignore_bots: true, log_mode: log_mode)

      @ready_count = 0
      @bot.ready do
        @ready_count += 1
        @bot.update_status(:dnd, "Restarted: #{@ready_count} times", nil) 
      end

      @hb_count = 0
      @bot.heartbeat do
        @bot.update_status(:online, "/poll | ex/poll | #{@bot.servers.size} guilds", nil) if @hb_count % 15 == 0
        @hb_count += 1
      end

      Response.events(@bot)
      Canceler.events(@bot)
      Poll.events(@bot)
      Admin.events(@bot)
    end

    def run(background = false)
      @bot.run(background)
    end
  end
end
