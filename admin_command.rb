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

      split_log(log, 2000).each { |log| event.send(log) }
    end
  end

  def split_log(log, limit)
    logs = []
    part = "```\n"

    log.each_line do |line|
      if part.size + line.size > limit - 3
        logs << "#{part}```" 
        part = "```\n"
      end
      part += line
    end

    logs << "#{part}```" 
  end
end
