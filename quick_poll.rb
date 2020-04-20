require 'bundler/setup'
require 'discordrb'

require_relative './check_emoji'
require_relative './poll_commands'
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

    set_commands

    # リアクションイベント
    @bot.reaction_add do |event|
      if event.message.from_bot?
        exclusive_reaction(event)
      else
        destroy_relate(event)
      end
      nil
    end

    set_admin_command
  end

  def run(async = false)
    @bot.run(async)
  end

  private

  # ヘルプ表示
  def show_help(event)
    message = event.send_embed do |embed|
      embed.color = COLOR_HELP
      embed.title = "Quick Poll の使い方"
      embed.description = <<DESC
**```#{@bot.prefix}poll 質問文 選択肢1 選択肢2 選択肢3...```**
コマンドの後に質問文・選択肢を入力すると、それを元に投票を作ります。
選択肢は0～20個指定でき、メンバーは「🇦 🇧 🇨...」の選択肢の中から回答することができます。

質問文・選択肢の区切りは **半角スペース** か **改行** です。
質問文・選択肢に半角スペースを含めたい場合は **`"`** で囲ってください。

**```#{@bot.prefix}expoll 質問文 選択肢1 選択肢2 選択肢3...```**
選択肢を1つしか選べない投票を作ります。
使用方法は `#{@bot.prefix}poll` と同じです。

**```#{@bot.prefix}freepoll 質問文```**
選択肢を作らず、メンバーが任意で付けたリアクションの数を集計する投票を作ります。

コマンド実行後、1分以内に↩️を押すとコマンドを取り消すことができます。

[より詳しい使い方](https://github.com/GrapeColor/quick_poll/blob/master/README.md)
DESC
    end

    create_relate(event, message)
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
    message = event.send_embed do |embed|
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

    create_relate(event, message)
  end

  # 排他リアクション処理
  def exclusive_reaction(event)
    message = event.message
    embed = message.embeds.first
    return if embed.color != COLOR_QUESTION
    return if embed.footer.nil?

    # イベントを発生させたリアクション以外を削除
    message.reactions.each do |reaction|
      next if event.emoji.to_reaction == reaction.to_s
      message.delete_reaction(event.user, reaction.to_s)
    end
  end
end
