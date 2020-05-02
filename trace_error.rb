# frozen_string_literal: true

class QuickPoll
  CHANNEL_TYPES = Discordrb::Channel::TYPES.keys.freeze
  NEED_PERMISSIONS = [
    :read_messages,
    :send_messages,
    :manage_messages,
    :embed_links,
    :read_message_history,
    :add_reactions,
    :use_external_emoji,
  ].freeze

  private

  def trace_error(event, e)
    server = event.server
    channel = event.channel
    user = event.user
    message = event.message
    own = server&.bot
    attachments = message.attachments.map(&:url).join("\n")
    admin_user = @bot.user(ENV['ADMIN_USER_ID'])

    admin_user.dm.send_embed do |embed|
      embed.color = COLOR_ERROR
      embed.title = "⚠️ エラーレポート"
      embed.timestamp = message.timestamp

      embed.add_field(name: "実行コマンド", value: "```#{message.content}```")
      embed.add_field(
        name: "添付ファイル",
        value: "```#{attachments}```"
      ) if attachments != ""

      embed.add_field(
        name: "サーバー・チャンネル・ユーザー情報",
        value: "```\n#{"#{server.name}: #{server.id}\n" if server}" +
          "#{channel.name} (#{CHANNEL_TYPES[channel.type]} channel): #{channel.id}\n" +
          "#{user.distinct}: #{user.id}\n```"
      )
      embed.add_field(
        name: "BOT権限情報",
        value: "```\n#{check_permission_list(own, channel)}\n```"
      ) if own

      embed.add_field(
        name: "例外クラス",
        value: "```#{e.inspect}```"
      )
      split_backtrace(e).each.with_index(1) do |log, i|
        embed.add_field(name: "バックトレース#{i}", value: log)
      end
    end

    send_error(
      event.channel, event.message,
      "予期しない原因でコマンドの実行に失敗しました",
      "開発者にエラーを報告しました"
    )
  end

  def check_permission_list(member, channel)
    NEED_PERMISSIONS.map do |action|
      "#{member.permission?(action, channel) ? "✓" : "✗"} #{action}"
    end.join("\n")
  end

  def split_backtrace(e)
    log = "#{e.backtrace.join("\n")}\n"
    logs = []
    part = "```\n"

    log.each_line do |line|
      if part.size + line.size > 1021 # Field's value limitation - ``` (1024 - 3)
        logs << "#{part}```" 
        part = "```\n"
      end
      part += line
    end

    logs << "#{part}```" 
  end
end
