# frozen_string_literal: true

module QuickPoll
  class ImpossibleSend < StandardError; end

  class Response
    include Base

    def self.events(bot)
      @@server_prefixes ||= Hash.new('/')
      bot.ready do
        bot.servers.each { |_, server| update_prefix(server) }
      end

      bot.member_update do |event|
        update_prefix(event.server) if event.user.current_bot?
      end

      @@command_count = Hash.new(0)
      bot.message { |event| parse(event) }

      bot.mention do |event|
        return if event.content !~ /^<@!?#{bot.profile.id}>$/
        information(event)
      end
    end

    def self.update_prefix(server)
      @@server_prefixes[server.id] = server.bot.nick.to_s =~ /^\[(\S{1,8})\]/ ? $1 : '/'
    end

    def self.parse(event)
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
      self.new(event, prefix, ex, args)

      nil
    end

    def self.parse_content(content)
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

    def self.information(event)
      prefix = @@server_prefixes[event.server&.id]

      help = event.send_embed do |embed|
        embed.color = COLOR_HELP
        embed.title = "📊 Quick Poll情報"
        embed.description = <<~DESC
          コマンドプレフィックス: `#{prefix}`
          チュートリアル表示コマンド: `#{prefix}poll`
          導入サーバー数: `#{event.bot.servers.size}`

          [更新情報・質問・不具合報告](#{SUPPORT_URL})
        DESC
      end

      Canceler.new(event.message, help)
    end

    def initialize(event, prefix, ex, args)
      @event = event
      @prefix = prefix
      @ex = ex
      @args = args

      response = call_responser
    rescue ImpossibleSend
      return
    rescue => e
      trace_error(e)
    else
      Canceler.new(event.message, response)
    end

    private

    def call_responser
      return Help.new(@event, @prefix) if @args.size <= 1

      if @args[0] != "sumpoll"
        Poll.new(@event, @prefix, @ex, @args)
      else
        Result.new(@event, args[1])
      end
    end

    def trace_error(e)
      @channel = @event.channel
      @message = @event.message
      @own = @event.server&.bot

      attachments = @message.attachments.map(&:url).join("\n")
      admin_user = @event.bot.user(ENV['ADMIN_USER_ID'])

      admin_user.dm.send_embed do |embed|
        embed.color = COLOR_ERROR
        embed.title = "⚠️ エラーレポート"
        embed.timestamp = @message.timestamp

        embed.add_field(name: "実行コマンド", value: "```#{@message.content}```")
        embed.add_field(name: "添付ファイル", value: "```#{attachments}```") if attachments != ""
        embed.add_field(name: "BOT権限情報", value: "```#{permission_list}```") if @own

        embed.add_field(name: "例外クラス", value: "```#{e.inspect}```")
        backtraces = Admin.split_log("#{e.backtrace.join("\n")}\n", 1024)
        backtraces.each.with_index(1) do |trace, i|
          embed.add_field(name: "バックトレース-#{i}", value: trace)
        end
      end

      send_error(
        "予期しない原因でコマンドの実行に失敗しました",
        "開発者にエラー情報を送信しました"
      )
    end

    def permission_list
      NEED_PERMISSIONS.map do |action|
        "#{@own.permission?(action, @channel) ? "✓" : "✗"} #{action}"
      end.join("\n")
    end
  end
end
