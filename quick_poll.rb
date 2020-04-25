require 'bundler/setup'
require 'discordrb'

require_relative './check_emoji'
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

    @bot.ready { @bot.game = "/poll" }

    poll_commands
    result_command

    set_admin_command
  end

  def run(async = false)
    @bot.run(async)
  end
end
