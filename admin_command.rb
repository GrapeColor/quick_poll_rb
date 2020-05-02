# frozen_string_literal: true

class QuickPoll
  private

  def set_admin_command
    @bot.dm do |event|
      next if event.author != ENV['ADMIN_USER_ID']
      next if event.content !~ /^<@!?#{@bot.profile.id}>\s+admin\R?```(ruby)?\R?(.+)\R?```/m

      $stdout = StringIO.new

      begin
        $2.split("\n\n").each { |code| eval("pp(#{code})") }
        log = $stdout.string
      rescue => e
        log = e
      end

      $stdout = STDOUT

      log.to_s.scan(/.{1,#{2000 - 8}}/m) do |split|
        event.send("```\n#{split}\n```")
      end
    end
  end
end
