# frozen_string_literal: true

require 'bundler/setup'
require 'discordrb'

require_relative './poll_commands'
require_relative './create_poll'
require_relative './trace_error'
require_relative './help_command'
require_relative './admin_command'

class QuickPoll
  SUPPORT_URL = "https://discord.gg/STzZ6GK"

  def initialize(token)
    @bot = Discordrb::Commands::CommandBot.new(token: token, ignore_bots: true)

    @ready_count = 0
    @bot.ready do
      @bot.update_status(:dnd, @ready_count > 0 ? "Reconnected: #{@ready_count}times" : "Restarted", nil)
      @ready_count += 1

      listup_server_prefixes
    end

    @hb_count = 0
    @bot.heartbeat do
      case @hb_count % 6
      when 0
        @bot.update_status(:online, "/poll | ex/poll", nil)
      when 3
        @bot.update_status(:online, "#{@bot.servers.size} guilds", nil)
      end
      @hb_count += 1
    end

    @bot.mention do |event|
      return if event.content !~ /^<@!?#{@bot.profile.id}>$/

      prefix = @server_prefixes[event.server&.id]
      info = event.send_embed do |embed|
        embed.color = COLOR_HELP
        embed.title = "📊 Quick Poll情報"
        embed.description = <<~DESC
          コマンドプレフィックス: `#{prefix}`
          チュートリアル表示コマンド: `#{prefix}poll`
          導入サーバー数: `#{@bot.servers.size}`

          [更新情報・質問・不具合報告](#{SUPPORT_URL})
        DESC
      end
      await_cancel(event.message, info)
    end

    @bot.member_update { |event| update_server_prefix(event.server) if event.user.current_bot? }

    set_poll_commands
    set_admin_command
  end

  def run(async = false)
    @bot.run(async)
  end

  private

  def listup_server_prefixes
    @server_prefixes ||= Hash.new('/')
    @bot.servers.each { |_, server| update_server_prefix(server) }
  end

  def update_server_prefix(server)
    @server_prefixes[server.id] = server.bot.nick.to_s =~ /^\[(\S{1,8})\]/ ? $1 : '/'
  end
end
