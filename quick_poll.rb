require 'bundler/setup'
require 'discordrb'
require 'twemoji'

class QuickPoll
  DEFAULT_EMOJIS = ["🇦", "🇧", "🇨", "🇩", "🇪", "🇫", "🇬", "🇭", "🇮", "🇯", "🇰", "🇱", "🇲", "🇳", "🇴", "🇵", "🇶", "🇷", "🇸", "🇹"].freeze
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
      log_mode: :silent
    )

    @bot.ready { @bot.game = "#{@bot.prefix}poll" }

    @bot.bucket(:poll_limit, limit: 1, time_span: 5)

    @command_attrs = {
      rate_limit_message: "コマンドは **%time%秒後** に使用できます",
      bucket: :poll_limit
    }

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

      # 質問を表示
      show_question(event)
      nil
    end
  end

  # BOT起動
  def run(async = false)
    @bot.run(async)
  end

  private

  # 質問を表示
  def show_question(event)
    # 引数を分解
    args = parse_args(event.content)
    args.shift  # コマンド部を削除
    question = args.shift # 質問文
    if args.length > 20
      event.send_message("⚠ **選択肢は最大20個までです**")
      return
    end

    # 絵文字を抽出
    emojis = args.map { |arg| start_with_emoji(arg) }
    emoji_lengths = emojis.map { |emoji| emoji.length }

    if args.empty?
      # 質問文のみ
      emojis = "⭕", "❌"
    else
      if emoji_lengths.min < 1
        # 絵文字から始まらない選択肢がある場合
        emojis = DEFAULT_EMOJIS[0..(args.length - 1)]
      else
        # 選択肢がすべて絵文字で始まる場合
        if emojis.length - emojis.uniq.length > 0
          event.send_message("⚠ **選択肢の絵文字が重複しています**")
          return
        end

        args.each_with_index do |arg, i|
          arg.slice!(0..(emoji_lengths[i] - 1))
        end

        # カスタム絵文字を変換
        emojis.map! do |emoji|
          custom = @bot.parse_mention(emoji)
          custom.respond_to?(:to_reaction) ? custom.to_reaction : emoji
        end
      end
    end

    # メッセージを仮送信
    message = event.send_message("メッセージ生成中...")

    # 埋め込み生成
    embed = Discordrb::Webhooks::Embed.new
    embed.color = COLOR_QUESTION
    embed.author = Discordrb::Webhooks::EmbedAuthor.new(
      icon_url: event.author.avatar_url,
      name: event.author.display_name
    )
    embed.title = "🇶 #{question}"
    embed.description = ""
    args.each_with_index do |arg, i|
      embed.description += "#{emojis[i]} #{arg}\n" unless arg.empty?
    end
    embed.description += "\n投票結果は `#{@bot.prefix}poll #{message.id}` で表示できます。"

    # 埋め込みの反映とリアクションの生成
    message.edit("", embed)
    emojis.each { |emoji| message.create_reaction(emoji) }
  end

  # 投票結果表示
  def show_result(event, message_id)
    message = event.channel.load_message(message_id)
    return if message.nil?

    # メッセージを検証
    return if message.author.id != @bot.profile.id
    q_embed = message.embeds.first
    return if q_embed.color != COLOR_QUESTION

    # 質問文解析
    q_embed.title =~ /^🇶 (.+)/
    question = $1
    options = []
    q_embed.description.lines do |line|
      option = line.chomp
      break if option.empty?

      option =~ /^(.+) (.+)$/
      options << { emoji: $1.strip, text: $2 }
    end

    # 集計
    reactions = message.my_reactions
    polls = reactions.map do |reaction|
      emoji = reaction.to_s
      emoji = "<:#{emoji}>" if emoji =~ /.+:\d+/
      [emoji, reaction.count - 1]
    end.to_h
    polls_max = [polls.values.max, 1].max
    polls_sum = [polls.values.inject(:+), 1].max

    # フィールドの文字列生成
    results = options.map do |option|
      count = polls[option[:emoji]]
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
      embed.title = "🅰\uFE0F #{question}"
      options.each_with_index do |option, i|
        embed.add_field(
          name: "#{option[:emoji]} **#{option[:text]}**",
          value: results[i]
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
コマンドの後に質問文・選択肢を入力すると、それを元に投票用のメッセージを生成します。
選択肢は0～20個指定でき、選択肢の先頭に絵文字を使うと、その絵文字が選択肢になります。

質問文・選択肢の区切りは **半角スペース** か **改行** です。
質問文・選択肢に半角スペースを含めたい場合は **`"`** か **`'`** で囲ってください。
**`"`** や **`'`** は **`\\`** でエスケープできます。

例：（どちらも同じ結果になります）
```
#{@bot.prefix}poll 好きなラーメンの味は？ 醤油 豚骨 味噌 塩

#{@bot.prefix}poll
好きなラーメンの味は？
醤油
豚骨
味噌
塩
```
DESC
    end
  end

  # 引数の分解
  def parse_args(content)
    args = []
    arg = ""
    quote = ""
    escape = false

    # 引数追加手続き
    add_arg = Proc.new {
      args << arg unless arg.empty?
      arg = ""
    }

    content.chars.each.with_index(1) do |char, i|
      # クォート
      if char =~ /["']/ && !escape
        if quote.empty?
          quote = char
          add_arg.call
          next
        end

        if quote == char
          quote = ""
          add_arg.call
          next
        end
      end

      # クォートのエスケープ
      if content[i] && char + content[i] =~ /\\["']/
        escape = true
        next
      end
      escape = false if escape

      # 引数の区切り(半角スペース)
      if char == " " && quote.empty?
        add_arg.call
        next
      end

      # 改行
      if char == "\n"
        quote = ""
        add_arg.call
        next
      end

      arg += char
    end
    add_arg.call

    args
  end

  # 先頭何文字分が絵文字か
  def start_with_emoji(content)
    emoji = ""
    max = [content.length, 8].max

    # カスタム絵文字
    content =~ /^<:.+:\d+>/
    return $& if $& && @bot.parse_mention($&).respond_to?(:to_reaction)

    # デフォルト絵文字
    (0...max).each do |index|
      end_index = max - index
      if Twemoji.find_by(unicode: content[0...end_index])
        emoji = content[0...end_index]
        emoji += content[end_index] if content[end_index] == "\uFE0F" # 字形選択子を含める
        break
      end
    end

    emoji
  end
end
