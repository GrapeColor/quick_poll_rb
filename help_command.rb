# frozen_string_literal: true

class QuickPoll
  COLOR_HELP = 0xff922f
  INVITE_URL = "https://discordapp.com/api/oauth2/authorize?client_id=631159438337900575&permissions=355392&scope=bot"

  private

  def show_help(event, prefix)
    help = send_waiter(event.channel, "ヘルプ表示生成中...") rescue return

    embed = Discordrb::Webhooks::Embed.new
    embed.color = COLOR_HELP
    embed.title = "📊 Quick Pollの使い方"
    embed.url = "https://github.com/GrapeColor/quick_poll/wiki/%E4%BD%BF%E7%94%A8%E6%96%B9%E6%B3%95"

    embed.description = <<~DESC
      🇦 🇧 🇨 🇩 …で選択できる投票を作る
      ```#{prefix}poll 好きな果物は？ りんご ぶどう みかん キウイ```
      任意の絵文字で選択できる投票を作る
      ```#{prefix}poll 好きな果物は？ 🍎 りんご 🍇 ぶどう 🍊 みかん 🥝 キウイ```
      絵文字だけを選択できる投票を作る
      ```#{prefix}poll 好きな果物は？ 🍎 🍇 🍊 🥝```
      ⭕ ❌ の二択で選択できる投票を作る
      ```#{prefix}poll メロンは果物である```
      任意の数だけの 🇦 🇧 🇨 🇩 …で選択できる絵文字だけの投票を作る
      ```#{prefix}numpoll どのチームに入る？ 4```
      リアクションの数だけを集計できる投票を作る
      ```#{prefix}freepoll 好きな絵文字を教えて```
      Tips
      ```yaml
      投票の選択肢は最大20個まで。
      文・絵文字の区切りは半角スペースか、改行が使用できます。
      文中に半角スペースを含めたい場合、"" で文を囲んでください。
      コマンドと一緒に画像を添付すると、画像付きの投票を作成します。
      コマンドの前に 'ex' を付けると1人1票だけの投票を作成します。
      BOTのニックネームの頭に[(任意1～8文字)]を付けると、プレフィックスを変更できます。
      ```
      ↩️ でコマンド実行をキャンセル(60秒以内)

      🈂️ [更新情報・質問・不具合報告](#{SUPPORT_URL})　➡️ **[サーバーへ追加](#{INVITE_URL})**
    DESC

    help.edit("", embed)
  end
end
