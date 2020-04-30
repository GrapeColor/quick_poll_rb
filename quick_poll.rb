# frozen_string_literal: true

require 'bundler/setup'
require 'discordrb'

require_relative './poll_commands'
require_relative './result_command'
require_relative './help_command'
require_relative './admin_command'

class QuickPoll
  def initialize(token)
    @bot = Discordrb::Commands::CommandBot.new(
      token: token,
      prefix: '/',
      help_command: false,
      webhook_commands: false,
      ignore_bots: true
    )

    @ready_count = 0
    @bot.ready do
      @bot.update_status(:dnd, "Reconnected: #{@ready_count}", nil) if @ready_count > 0
      @ready_count += 1
    end

    @hb_count = 0
    @bot.heartbeat do
      case @hb_count % 6
      when 0
        @bot.update_status(:online, "/poll /expoll /freepoll", nil)
      when 3
        @bot.update_status(:online, "#{@bot.servers.size} guilds", nil)
      end
      @hb_count += 1
    end

    set_poll_commands
    set_result_command
    set_admin_command
  end

  def run(async = false)
    @bot.run(async)
  end
end
