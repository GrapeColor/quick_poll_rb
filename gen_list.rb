require 'yaml'

EMOJI_PATH = 'twemoji/assets/svg'

emojis = []
Dir.foreach(EMOJI_PATH) do |f|
  code_points = $1.split("-") if f =~ /(.+).svg/
  next if code_points.nil?
  emoji = ""
  code_points.each { |point| emoji << point.to_i(16).chr("UTF-8") }
  emojis << emoji unless emoji.empty?
end

YAML.dump(emojis, File.open('emoji_list.yml', 'w'))

# twemojiの絵文字リストファイル、「emoji_list.yml」を生成します。
# 同じディレクトリに(https://github.com/twitter/twemoji)をcloneしてください。
