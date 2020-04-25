class QuickPoll
  private

  def set_admin_command
    @bot.mention(in: ENV['ADMIN_CHANNEL_ID'].to_i, from: ENV['ADMIN_USER_ID'].to_i) do |event|
      next if event.content !~ /^<@!?\d+>\s+admin\R?```(ruby)?\R?(.+)\R?```/m

      $stdout = StringIO.new

      begin
        $2.split("\n\n").each do |code|
          eval("pp(#{code})")
        end
        log = $stdout.string
      rescue => exception
        log = exception
      end

      $stdout = STDOUT

      log.to_s.scan(/.{1,#{2000 - 8}}/m) do |split|
        event.send("```\n#{split}\n```")
      end
    end
  end
end
