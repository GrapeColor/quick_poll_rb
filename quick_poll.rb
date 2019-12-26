require 'bundler/setup'
require 'discordrb'
require 'yaml'

class String
  EMOJI_FILE = File.expand_path('../emoji_list.yml', __FILE__)
  EMOJI_LIST = File.open(EMOJI_FILE, 'r') { |f| YAML.load(f) }

  # レシーバが絵文字か
  def emoji?
    return true if self =~ /^<:.+:\d+>$/
    EMOJI_LIST.include?(self.delete("\uFE0F"))
  end
end

class QuickPoll
  DEFAULT_EMOJIS = ["🇦", "🇧", "🇨", "🇩", "🇪", "🇫", "🇬", "🇭", "🇮", "🇯", "🇰", "🇱", "🇲", "🇳", "🇴", "🇵", "🇶", "🇷", "🇸", "🇹"]
  COLOR_QUESTION = 0x3b88c3
  COLOR_ANSWER   = 0xdd2e44
  COLOR_HELP     = 0x77b255

  def initialize(token)
    @bot = Discordrb::Commands::CommandBot.new(
      token: token,
      prefix: "/",
      help_command: false,
      webhook_commands: false,
      ignore_bots: true,
      # log_mode: :silent
    )

    @bot.ready { @bot.game = "#{@bot.prefix}poll" }

    @bot.bucket(:poll_limit, limit: 1, time_span: 5)

    rate_limit = {
      rate_limit_message: "⚠️ コマンドは **%time%秒後** に再び使用できます",
      bucket: :poll_limit
    }

    # 通常の投票コマンド
    @bot.command(:poll, rate_limit) do |event, *args|
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
      create_question(event)
      nil
    end

    # 排他的投票コマンド
    @bot.command(:expoll, rate_limit) do |event, *args|
      # ヘルプ表示
      if args.empty?
        show_help(event)
        next nil
      end

      # 投票を表示
      create_question(event)
      nil
    end

    # 自由選択肢投票コマンド
    @bot.command(:freepoll, rate_limit) do |event, arg|
      # ヘルプ表示
      if arg.nil?
        show_help(event)
        next nil
      end

      # 投票を表示
      create_question(event, true)
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

  def sync
    @bot.sync
  end

  private

  # ヘルプ表示
  def show_help(event)
    event.send_embed do |embed|
      embed.color = COLOR_HELP
      embed.title = "Quick Poll の使い方"
      embed.description = <<DESC
**```#{@bot.prefix}poll 質問文 選択肢1 選択肢2 選択肢3...```**
コマンドの後に質問文・選択肢を入力すると、それを元に投票を作ります。
選択肢は0～20個指定でき、メンバーは「🇦 🇧 🇨...」の選択肢の中から回答することができます。
選択肢が0個の場合は、メンバーに⭕と❌の中から選ばせる投票を作ります。

**```#{@bot.prefix}poll 質問文 絵文字1 選択肢1 絵文字2 選択肢2 絵文字3 選択肢3...```**
絵文字を選択肢の **前に** 入れると、指定された絵文字が選択肢として使えます。
その場合はすべての選択肢に絵文字を指定する必要があります。

質問文・絵文字・選択肢の区切りは **半角スペース** か **改行** です。
質問文・選択肢に半角スペースを含めたい場合は **`"`** で囲ってください。

**```#{@bot.prefix}expoll 質問文 選択肢1 選択肢2 選択肢3...```**
選択肢を1つしか選べない投票を作ります。
使用方法は `#{@bot.prefix}poll` と同様です。

**```#{@bot.prefix}freepoll 質問文```**
選択肢を作らず、メンバーが任意で付けたリアクションの数を集計する投票を作ります。

[詳しい使用方法](https://github.com/GrapeColor/quick_poll/blob/master/README.md)
DESC
    end
  end

  # 投票を表示
  def create_question(event, free = false)
    # 引数を分解
    args = parse_args(event.content)
    command  = args.shift       # コマンド部
    question = args.shift       # 質問文

    # 選択肢を生成
    # 選択肢はあるか
    if args.any?
      # 引数が絵文字か判別
      are_emoji = args.map(&:emoji?)

      # すべての引数が絵文字か
      if are_emoji.all?
        emojis  = args
        options = []
      else
        # 引数が絵文字と選択文のペアか
        if are_emoji.each_slice(2).map { |i, j| i & !j }.all?
          emojis, options = args.partition.with_index { |_, i| i.even? }
        else
          emojis  = DEFAULT_EMOJIS[0...args.length]
          options = args
        end
      end

      # 選択肢数を確認
      if emojis.length > 20 || options.length > 20
        event.send_message("⚠️ **選択肢は最大20個までです**")
        return
      end

      # 絵文字の重複確認
      if emojis.length - emojis.uniq.length > 0
        event.send_message("⚠️ **選択肢の絵文字が重複しています**")
        return
      end
    else
      emojis  = free ? [] : ["⭕", "❌"]
      options = []
    end

    # メッセージを仮送信
    message = event.send_message("⌛ メッセージ生成中...")

    # 投稿者名取得
    if event.author.respond_to?(:display_name)
      username = event.author.display_name
    else
      username = event.author.username
    end

    # 埋め込み生成
    embed = Discordrb::Webhooks::Embed.new
    embed.color = COLOR_QUESTION
    embed.author = Discordrb::Webhooks::EmbedAuthor.new(
      icon_url: event.author.avatar_url,
      name: username
    )
    embed.title = "🇶 #{question}\u200c"
    embed.description = ""
    options.each_with_index do |option, i|
      embed.description += "#{emojis[i]} #{option}\n"
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
    return unless message.from_bot?
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
      option = line.strip
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

      # 各選択肢の結果を挿入
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

  # 排他リアクション処理
  def exclusive_reaction(event)
    message = event.message
    return if message.embeds.first.footer.nil?

    # イベントを発生させたリアクション以外を削除
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
      args << arg.strip unless arg.empty?
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
end
