# frozen_string_literal: true

module QuickPoll
  class Help
    include Base

    def initialize(event, prefix)
      @channel = event.channel
      @response = send_waiter("ヘルプ表示生成中...")

      embed = Discordrb::Webhooks::Embed.new
      embed.color = COLOR_HELP
      embed.title = "📊 Quick Pollの使い方"
      embed.url = "https://github.com/GrapeColor/quick_poll/wiki/使用方法"

      embed.description = <<~DESC
        🇦 🇧 🇨 🇩 …で選択できる投票を作る
        ```yaml
        #{prefix}poll 好きな果物は？ りんご ぶどう みかん キウイ
        ```
        任意の絵文字で選択できる投票を作る
        ```yaml
        #{prefix}poll 好きな果物は？ 🍎 りんご 🍇 ぶどう 🍊 みかん 🥝 キウイ
        ```
        ⭕ ❌ の二択で選択できる投票を作る
        ```yaml
        #{prefix}poll メロンは果物である
        ```
        ひとり一票だけの投票を作る
        ```yaml
        ex#{prefix}poll "Party Parrotは何て動物？" インコ フクロウ カカポ オウム
        ```
        Tips
        ```diff
        - 投票の選択肢は最大20個まで
        - 文・絵文字の区切りは半角スペースか、改行
        - 文中に半角スペースを含めたい場合、"" で文を囲む
        - コマンドに画像を添付すると、画像付きの投票を作成
        ```
        ↩️ でコマンド実行をキャンセル(60秒以内)

        🈂️ [更新情報・質問・不具合報告](#{SUPPORT_URL})　\
        ➡️ **[サーバーへ追加](#{event.bot.invite_url(permission_bits: PERMISSION_BITS)})**
      DESC

      @response.edit("", embed)
    end

    attr_reader :response
  end
end
