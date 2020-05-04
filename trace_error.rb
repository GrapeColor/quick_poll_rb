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
      embed.add_field(name: "添付ファイル", value: "```#{attachments}```") if attachments != ""
      embed.add_field(name: "BOT権限情報", value: "```#{check_permission_list(own, channel)}```") if own

      embed.add_field(name: "例外クラス", value: "```#{e.inspect}```")
      backtraces = split_log("#{e.backtrace.join("\n")}\n", 1024)
      backtraces.each.with_index(1) do |trace, i|
        embed.add_field(name: "バックトレース-#{i}", value: trace)
      end
    end

    send_error(
      channel, message,
      "予期しない原因でコマンドの実行に失敗しました",
      "開発者にエラー情報を送信しました"
    )
  end

  def check_permission_list(member, channel)
    NEED_PERMISSIONS.map do |action|
      "#{member.permission?(action, channel) ? "✓" : "✗"} #{action}"
    end.join("\n")
  end
end
