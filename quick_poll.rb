require 'bundler/setup'
require 'discordrb'
require 'yaml'

class QuickPoll
  DEFAULT_EMOJIS = ["🇦", "🇧", "🇨", "🇩", "🇪", "🇫", "🇬", "🇭", "🇮", "🇯", "🇰", "🇱", "🇲", "🇳", "🇴", "🇵", "🇶", "🇷", "🇸", "🇹"]
  COLOR_QUESTION = 0x3b88c3
  COLOR_ANSWER   = 0xdd2e44
  COLOR_HELP     = 0x77b255

  EMOJI_FILE = File.expand_path('../emoji_list.yml', __FILE__)
  EMOJI_LIST = File.open(EMOJI_FILE, 'r') { |f| YAML.load(f) }

  def initialize(token)
    @bot = Discordrb::Commands::CommandBot.new(
      token: token,
      prefix: "/",
      help_command: false,
      webhook_commands: false,
      ignore_bots: true,
      log_mode: :silent
    )

    @bot.ready { @bot.game = "#{@bot.prefix}poll" }

    @bot.bucket(:poll_limit, limit: 1, time_span: 5)

    @command_attrs = {
      rate_limit_message: "⚠️ コマンドは **%time%秒後** に再び使用できます",
      bucket: :poll_limit
    }

    # 通常の投票コマンド
    @bot.command(:poll, @command_attrs) do |event, *args|
      # ヘルプ表示
      if args.empty?
        show_help(event)
        next nil
      end

      # 投票結果表示
      if args.length == 1 && args[0] =~ /^\d+$/
        show_result(event, $&.to_i)
        next nil
      end

      # 投票を表示
      show_question(event)
      nil
    end

    # 排他的投票コマンド
    @bot.command(:expoll, @command_attrs) do |event, *args|
      # ヘルプ表示
      if args.empty?
        show_help(event)
        next nil
      end

      # 投票を表示
      show_question(event)
      nil
    end

    # 自由選択肢投票コマンド
    @bot.command(:freepoll, @command_attrs) do |event, arg|
      # ヘルプ表示
      if arg.nil?
        show_help(event)
        next nil
      end

      # 投票を表示
      show_question(event)
      nil
    end

    # リアクションイベント
    @bot.reaction_add do |event|
      exclusive_reaction(event)
      nil
    end
  end

  # BOT起動
  def run(async = false)
    @bot.run(async)
  end

  private

  # 投票を表示
  def show_question(event)
    # 引数を分解
    args = parse_args(event.content)
    command = args.shift  # コマンド部
    question = args.shift # 質問文
    if args.length > 20
      event.send_message("⚠️ **選択肢は最大20個までです**")
      return
    end

    # 選択肢の絵文字を生成
    if args.empty?
      # 質問文のみ
      command == "#{@bot.prefix}freepoll" ? emojis = [] : emojis = ["⭕", "❌"]
    else
      # 先頭絵文字を抽出
      emojis = args.map { |arg| start_with_emoji(arg) }
      emoji_lengths = emojis.map { |emoji| emoji.length }

      if emoji_lengths.min < 1
        # 絵文字から始まらない選択肢がある場合
        emojis = DEFAULT_EMOJIS[0...args.length]
      else
        # 選択肢がすべて絵文字で始まる場合

        # 絵文字の重複確認
        if emojis.length - emojis.uniq.length > 0
          event.send_message("⚠️ **選択肢の絵文字が重複しています**")
          return
        end

        # 先頭の絵文字を削除
        args.each_with_index do |arg, i|
          arg.slice!(0...emoji_lengths[i])
          arg.strip!
        end
      end
    end

    # メッセージを仮送信
    message = event.send_message("⌛ メッセージ生成中...")

    # 投稿者名取得
    if event.author.respond_to?(:display_name)
      display_name = event.author.display_name
    else
      display_name = event.author.username
    end

    # 埋め込み生成
    embed = Discordrb::Webhooks::Embed.new
    embed.color = COLOR_QUESTION
    embed.author = Discordrb::Webhooks::EmbedAuthor.new(
      icon_url: event.author.avatar_url,
      name: display_name
    )
    embed.title = "🇶 #{question}\u200c"
    embed.description = ""
    args.each_with_index do |arg, i|
      embed.description += "#{emojis[i]} #{arg}\n" unless arg.empty?
    end
    embed.description += "\n投票結果は `#{@bot.prefix}poll #{message.id}` で表示できます。"
    embed.footer = Discordrb::Webhooks::EmbedFooter.new(
      text: "1人1つの選択肢だけ選べます"
    ) if command == "#{@bot.prefix}expoll"

    # 埋め込みの表示とリアクションの生成
    message.edit("", embed)
    emojis.each do |emoji|
      if emoji =~ /<:(.+:\d+)>/
        message.create_reaction($1)
      else
        message.create_reaction(emoji)
      end
    end
  end

  # 投票結果表示
  def show_result(event, message_id)
    message = event.channel.load_message(message_id)
    return if message.nil?

    # メッセージを検証
    return if message.author.id != @bot.profile.id
    q_embed = message.embeds.first
    return if q_embed.color != COLOR_QUESTION

    # 集計
    reactions = message.my_reactions
    reactions = message.reactions if reactions.empty?
    polls = reactions.map do |reaction|
      emoji = reaction.to_s
      emoji = "<:#{emoji}>" if emoji =~ /.+:\d+/
      next [emoji, reaction.count] unless reaction.me
      [emoji, reaction.count - 1]
    end.to_h
    polls_max = [polls.values.max, 1].max
    polls_sum = [polls.values.inject(:+), 1].max

    # 投票埋め込み解析
    q_embed.title =~ /🇶 (.+)/
    question = $1
    options = Hash.new("\u200c")  # ゼロ幅文字をデフォルト値に
    q_embed.description.lines do |line|
      option = line.chomp
      break if option.empty?

      option =~ /([^ ]+) (.+)/
      options[$1] = $2
    end

    # フィールドの文字列生成
    results = polls.map do |emoji, count|
      if count == polls_max
        "**#{count}票 (#{100.0 * count / polls_sum}%)** 🏆"
      else
        "#{count}票 (#{100.0 * count / polls_sum}%)"
      end
    end

    # 埋め込み生成
    event.send_embed do |embed|
      embed.color = COLOR_ANSWER
      embed.author = Discordrb::Webhooks::EmbedAuthor.new(
        icon_url: q_embed.author.icon_url,
        name: q_embed.author.name
      )
      embed.title = "🅰️ #{question}\u200c"

      inline = polls.length > 7
      polls.each_with_index do |poll, i|
        emoji, count = poll
        embed.add_field(
          name: "#{emoji} **#{options[emoji]}**",
          value: "#{results[i]}#{"    \uFE0F" if inline}",
          inline: inline
        )
      end
    end
  end

  # ヘルプ表示
  def show_help(event)
    event.send_embed do |embed|
      embed.color = COLOR_HELP
      embed.title = "Quick Pollの使い方"
      embed.description = <<DESC
**`#{@bot.prefix}poll [質問文] [選択肢1] [選択肢2] [選択肢3]...`**
コマンドの後に質問文・選択肢を入力すると、それを元に投票を作ります。
選択肢は0～20個指定でき、すべての選択肢の先頭に絵文字を使うと、その絵文字が選択肢になります。

質問文・選択肢の区切りは **半角スペース** か **改行** です。
質問文・選択肢に半角スペースを含めたい場合は **`"`** で囲ってください。

**`#{@bot.prefix}expoll [質問文] [選択肢1] [選択肢2] [選択肢3]...`**
選択肢を1つしか選べない投票を作ります。
使用方法は `#{@bot.prefix}poll` と同様です。

**`#{@bot.prefix}freepoll [質問文]`**
選択肢を作らず、メンバーが任意で付けたリアクションの数を集計する投票を作ります。

[詳しい使用方法](https://github.com/GrapeColor/quick_poll/blob/master/README.md)
DESC
    end
  end

  # 排他リアクション処理
  def exclusive_reaction(event)
    message = event.message
    return if message.embeds.first.footer.text.empty?

    message.reactions.each do |reaction|
      next if event.emoji.to_reaction == reaction.to_s
      message.delete_reaction(event.user, reaction.to_s)
    end
  end

  # 引数の分解
  def parse_args(content)
    args = []
    arg = ""
    quote = false
    escape = false

    # 引数追加手続き
    add_arg = Proc.new {
      args << arg unless arg.empty?
      arg = ""
    }

    content.chars.each.with_index(1) do |char, i|
      # クォート
      if char == '"' && !escape
        quote = !quote
        add_arg.call
        next
      end

      # クォートのエスケープ
      if char == '\\' && content[i] == '"'
        escape = true
        next
      end
      escape = false if escape

      # 引数の区切り(半角スペース)
      if char == " " && !quote
        add_arg.call
        next
      end

      # 改行
      if char == "\n"
        quote = false
        add_arg.call
        next
      end

      arg += char
    end
    add_arg.call

    args
  end

  # 先頭の絵文字を抽出
  def start_with_emoji(content)
    emoji = ""
    max = [content.length, 8].min

    # カスタム絵文字
    content =~ /^<:.+:\d+>/
    return $& if $& && @bot.parse_mention($&)

    # デフォルト絵文字
    (0...max).each do |index|
      end_index = max - index
      if EMOJI_LIST.include?(content[0...end_index])
        emoji = content[0...end_index]
        emoji += content[end_index] if content[end_index] == "\uFE0F" # 字形選択子を含める
        break
      end
    end

    emoji
  end
end
