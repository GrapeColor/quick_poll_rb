# frozen_string_literal: true

module QuickPoll
  class ImpossibleSend < StandardError; end

  class Response
    include Base

    def self.events(bot)
      @@prefixes = Hash.new('/')
      bot.ready do
        bot.servers.each { |_, server| update_prefix(server) }
      end

      bot.member_update do |event|
        update_prefix(event.server) if event.member.current_bot?
      end

      @@command_count = Hash.new(0)
      bot.message { |event| parse(event) }

      bot.mention do |event|
        next if event.content !~ /^<@!?#{bot.profile.id}>$/

        self.new(event, @@prefixes[event.server&.id], false, [])
        nil
      end
    end

    def self.update_prefix(server)
      match = server.bot.nick.to_s.match(/\[([!-~]{1,4}?)\]/)
      @@prefixes[server.id] = match ? match[1] : '/'
    end

    def self.parse(event)
      content = event.content
      server = event.server
      prefix = @@prefixes[server&.id]

      match_prefix = content.match(/^(ex)?#{Regexp.escape(prefix)}/)
      return unless match_prefix

      exclusive = !!match_prefix[1]
      content = content.delete_prefix("#{"ex" if exclusive}#{prefix}")
      args = parse_content(content)
      return unless COMMANDS.include?(args[0])

      @@command_count[event.channel.id] += 1
      self.new(event, prefix, exclusive, args)

      nil
    end

    def self.parse_content(content)
      args = []
      arg = quote = ""
      escape = false

      content.chars.each do |char|
        if !escape && (quote == "" || quote == char) && (char == '"' || char == "'" || char == '”' || char == '„')
          args << arg
          arg = ""
          quote = quote == "" ? char : ""
          quote = '”' if quote == '„'
          next
        end

        next if escape = char == "\\" && !escape

        if char == " " && quote == "" || char == "\n"
          args << arg 
          arg = quote = ""
          next
        end

        arg += char
      end

      args << arg
      args.reject(&:empty?)
    end

    def self.information(event)
      prefix = @@prefixes[event.server&.id]

      response = event.send_embed do |embed|
        embed.color = COLOR_HELP
        embed.title = "📊 Quick Poll情報"
        embed.description = <<~DESC
          コマンドプレフィックス: `#{prefix}`
          チュートリアル表示コマンド: `#{prefix}poll`
          導入サーバー数: `#{event.bot.servers.size}`

          [更新情報・ご質問・不具合報告](#{SUPPORT_URL})
        DESC
      end

      Canceler.new(event.message, response)
    end

    def initialize(event, prefix, exclusive, args)
      @event = event
      @channel = event.channel
      @prefix = prefix
      @exclusive = exclusive
      @args = args

      @response = call_responser
      Canceler.new(event.message, @response)
    rescue ImpossibleSend
      return
    rescue => e
      @response.delete rescue nil
      @response = trace_error(e)
      Canceler.new(event.message, @response)
    end

    private

    def call_responser
      return Help.new(@event, @prefix).response if @args.size <= 1

      if @args[0] == "sumpoll"
        Result.new(@event, @args[1]).response
      else
        Poll.new(@event, @prefix, @exclusive, @args).response
      end
    end

    def trace_error(e)
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
        "開発チームにエラー情報を送信しました"
      )
    end

    def permission_list
      NEED_PERMISSIONS.map do |action|
        "#{@own.permission?(action, @channel) ? "✓" : "✗"} #{action}"
      end.join("\n")
    end
  end
end
