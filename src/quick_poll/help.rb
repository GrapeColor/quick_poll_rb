# frozen_string_literal: true

module QuickPoll
  class Help
    include Base

    def initialize(event, prefix, response)
      embed = Discordrb::Webhooks::Embed.new
      embed.color = COLOR_HELP
      embed.title = "📊 Quick Pollの使い方"
      embed.url = "https://github.com/GrapeColor/quick_poll/wiki/使用方法"

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

        🈂️ [更新情報・質問・不具合報告](#{SUPPORT_URL})　\
        ➡️ **[サーバーへ追加](#{event.bot.invite_url(permission_bits: PERMISSION_BITS)})**
      DESC

      response.edit("", embed)
    end
  end
end
