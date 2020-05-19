# frozen_string_literal: true

module QuickPoll
  module Admin
    def self.events(bot)
      bot.dm do |event|
        next if event.author != ENV['ADMIN_USER_ID']
        next if event.content !~ /^<@!?#{bot.profile.id}>\s+admin\R?```(ruby)?\R?(.+)\R?```/m

        $stdout = StringIO.new

        begin
          $2.split("\n\n").each { |code| eval("pp(#{code})") }
          log = $stdout.string
        rescue => e
          log = "#{e.inspect}\n#{e.backtrace.join("\n")}"
        end

        $stdout = STDOUT

        split_log(log, 2000).each { |log| event.send(log) }
      end
    end

    def self.split_log(log, limit)
      logs = []
      part = "```"

      log.each_line do |line|
        if part.size + line.size > limit - 3
          logs << "#{part}```" 
          part = "```"
        end
        part += line
      end

      logs << "#{part}```" 
    end
  end
end
