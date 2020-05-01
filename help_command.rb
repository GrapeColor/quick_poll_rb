# frozen_string_literal: true

class QuickPoll
  COLOR_HELP = 0xff922f

  private

  def show_help(event)
    event.send_embed do |embed|
      embed.color = COLOR_HELP
      embed.title = "📊 Quick Pollの使い方"
      embed.url = "https://github.com/GrapeColor/quick_poll/wiki/%E4%BD%BF%E7%94%A8%E6%96%B9%E6%B3%95"

      embed.description = "🇦 🇧 🇨 🇩 …で選択できる投票を作る\n" +
        "```/poll 好きな果物は？ りんご ぶどう みかん キウイ```\n" +
        "任意の絵文字で選択できる投票を作る\n" +
        "```/poll 好きな果物は？ 🍎 りんご 🍇 ぶどう 🍊 みかん 🥝 キウイ```\n" +
        "絵文字だけを選択できる投票を作る\n" +
        "```/poll 好きな果物は？ 🍎 🍇 🍊 🥝```\n" +
        "⭕ ❌ の二択で選択できる投票を作る\n" +
        "```/poll メロンは果物である```\n" +
        "リアクションの数だけを集計できる投票を作る\n" +
        "```/freepoll 好きな果物を教えて```\n" +
        "Tips\n" +
        "```yaml\n" +
        "投票の選択肢は最大20個まで。\n" +
        "文・絵文字の区切りは半角スペースか、改行が使用できます。\n" +
        "文中に半角スペースを含めたい場合、\"\" で文を囲んでください。\n" +
        "コマンドと一緒に画像を添付すると、画像付きの投票を作成します。\n" +
        "```\n" +
        "↩️ でコマンド実行をキャンセル(60秒以内)\n" +
        "\n🈂️ [更新情報・質問・不具合報告](https://discord.gg/STzZ6GK)" +
        "　➡️ **[サーバーへ追加]" +
        "(https://discordapp.com/api/oauth2/authorize?client_id=631159438337900575&permissions=355392&scope=bot)**"
    end
  end
end
