# frozen_string_literal: true

module QuickPoll
  class Export < Result
    include Base

    def initialize(event, message_id)
      receive_args(event, message_id)

      @response = send_waiter("投票結果CSVファイル出力中...")

      unless can_send_file
        @response.delete
        @response = send_error(
          "CSVファイルが送信できません",
          "BOTに **ファイルを添付** 権限が必要です"
        )
        return
      end

      return unless is_poll? && parse_poll

      @io = StringIO.new

      poll = @poll
      @io.define_singleton_method(:path) { "#{poll.id}.csv" }

      generate_csv

      @response.delete
      @response = @channel.send_file(@io)
    end

    private

    def can_send_file
      @channel.private? || @channel.server.bot.permission?(:attach_files, @channel)
    end

    def generate_csv
      find_options = @options.values.all?

      @io.print("\xEF\xBB\xBF")
      @io.print("Emojis,Options,Votes,Rates,Members\n")

      @reactions.map.with_index do |reaction, i|
        count = @counts[i] 

        @io.print("#{reaction.name},")
        @io.print("\"#{@options[emoji_mention(reaction)]}\",")
        @io.print("#{count},")
        @io.printf("%.5f%%,", (100.0 * count / @total).round(5))

        @io.print('"')

        users = @poll.reacted_with(reaction.to_s)
        users.each do |user|
          next if user.current_bot?
          @io.print("#{user.distinct}, ")
        end
        @io.seek(-2, IO::SEEK_CUR) if count > 0

        @io.print("\"\n")
      end

      @io.rewind
    end
  end
end
