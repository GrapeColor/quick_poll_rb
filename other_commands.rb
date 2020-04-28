# frozen_string_literal: true

class QuickPoll
  private

  def set_other_commands
    @bot.command(:find_emoji) do |event, emoji_id|
      return if emoji_id.nil?

      emojis = if emoji_id =~ /^\d{7,}$/
        [@bot.emoji(emoji_id)].compact
      else
        @bot.emojis.select { |emoji| emoji.name =~ /#{emoji_id}/ }
      end

      message = event.send_embed do |embed|
        embed.color = 0x9867c6
        embed.title = "絵文字検索結果 (#{emojis.size} 件)"
        emojis[0...25].each do |emoji|
          embed.add_field(name: emoji.server.name, value: "#{emoji.mention} `:#{emoji.name}:`")
        end
        embed.footer = Discordrb::Webhooks::EmbedFooter.new(
          text: "26件以上の絵文字は表示できません"
        ) if emojis.size > 25
      end

      await_cancel(event.message, message)
    end
  end
end
