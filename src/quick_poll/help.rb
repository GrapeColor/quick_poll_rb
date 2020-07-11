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
      embed.url = HELP_URL

      embed.fields = [
        {
          name: "🇦 🇧 🇨 🇩 …で選択できる投票を作る",
          value: <<~VALUE
            ```fix
            #{prefix}poll 好きな果物は？ りんご ぶどう みかん キウイ
            ```
          VALUE
        },
        {
          name: "任意の絵文字で選択できる投票を作る",
          value: <<~VALUE
            ```fix
            #{prefix}poll 好きな果物は？ 🍎 りんご 🍇 ぶどう 🍊 みかん 🥝 キウイ
            ```
          VALUE
        },
        {
          name: "⭕ ❌ の二択で選択できる投票を作る",
          value: <<~VALUE
            ```fix
            #{prefix}poll メロンは果物である
            ```
          VALUE
        },
        {
          name: "ひとり一票だけの投票を作る",
          value: <<~VALUE
            ```fix
            ex#{prefix}poll "Party Parrotは何て動物？" インコ フクロウ カカポ オウム
            ```
          VALUE
        },
        {
          name: "🌟 Tips",
          value: <<~VALUE
            ```
            ● 投票の選択肢は最大20個まで
            ● 文・絵文字の区切りは半角スペースか改行
            ● 半角スペースを含めたい場合 "" で文を囲む
            ● 画像を添付すると画像付きの投票を作成
            ```
          VALUE
        },
        {
          name: "↩️ でコマンド実行をキャンセル(60秒以内)",
          value: <<~VALUE
            💟 [BOT開発・運用資金の寄付](#{DONATION_URL})
            ⚠️ [ご質問・不具合報告・更新情報](#{SUPPORT_URL})
            ➡️ **[サーバーへ追加](#{event.bot.invite_url(permission_bits: PERMISSION_BITS)})**
          VALUE
        }
      ]

      @response.edit("", embed)
    end

    attr_reader :response
  end
end
