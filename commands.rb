# frozen_string_literal: true

module QuickPoll
  module Commands
    include Base

    private

    def command_events
      @bot.ready { collect_prefixes }

      @bot.member_update do |event|
        update_server_prefix(event.server) if event.user.current_bot?
      end

      @@command_count = Hash.new(0)
      @bot.message { |event| parse_message(event) }
    end

    def collect_prefixes
      @@server_prefixes ||= Hash.new('/')
      @bot.servers.each { |_, server| update_prefix(server) }
    end

    def update_prefix(server)
      @@server_prefixes[server.id] = server.bot.nick.to_s =~ /^\[(\S{1,8})\]/ ? $1 : '/'
    end

    def parse_message(event)
      content = event.content
      server = event.server
      prefix = @@server_prefixes[server&.id]

      match_prefix = content.match(/^(ex)?#{Regexp.escape(prefix)}/)
      return unless match_prefix

      ex = !!match_prefix[1]
      args = parse_content(content)
      args[0].delete_prefix!("#{"ex" if ex}#{prefix}")
      return unless COMMANDS.include?(args[0])

      @@command_count[event.channel.id] += 1
      exec_command(event, prefix, ex, args)
      nil
    end

    def parse_content(content)
      args = []
      arg = quote = ""
      escape = false

      add_arg = -> do
        args << arg.strip if arg != ""
        arg = ""
      end

      content.chars.each do |char|
        if (char == '"' || char == "'" || char == '”') && (quote == "" || quote == char) && !escape
          quote = quote == "" ? char : ""
          add_arg.call
          next
        end

        next if escape = char == "\\" && !escape

        if char == " " && quote == "" || char == "\n"
          quote = ""
          add_arg.call
          next
        end

        arg += char
      end

      add_arg.call
      args
    end

    def exec_command(event, prefix, ex, args)
      channel = event.channel
      message = event.message

      if args.size <= 1
        Help.new(event, prefix)
        return
      end

      if args[0] == "sumpoll"
        Result.new(event, args[1])
        return
      end

      if ex && channel.private?
        send_error(
          channel, message,
          "DM・グループDM内では 'ex#{prefix}' プレフィックスが利用できません"
        )
        return
      end

      if ex && !event.server&.bot.permission?(:manage_messages, channel)
        send_error(
          channel, message, "'ex#{prefix}' プレフィックスが利用できません",
          "`ex#{prefix}` プレフィックスコマンドの実行にはBOTに **メッセージの管理** 権限が必要です"
        )
        return
      end

      Poll.new(event, prefix, ex, args)
    rescue => e
      trace_error(event, e)
    end

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
        backtraces = Admin.split_log("#{e.backtrace.join("\n")}\n", 1024)
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
end
