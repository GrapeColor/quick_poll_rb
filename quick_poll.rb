# frozen_string_literal: true

require 'bundler/setup'
require 'discordrb'

require_relative './poll_commands'
require_relative './result_command'
require_relative './help_command'
require_relative './other_commands'
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

    @status_switch = false
    @bot.heartbeat do
      if @status_switch = !@status_switch
        @bot.game = "/poll /expoll /freepoll"
      else
        @bot.watching = "#{@bot.servers.size} servers"
      end
    end

    set_poll_commands
    set_result_command
    set_other_commands
    set_admin_command
  end

  def run(async = false)
    @bot.run(async)
  end
end
