require 'yaml'

class String
  EMOJI_FILE = File.expand_path('../emoji_list.yml', __FILE__)
  EMOJI_LIST = File.open(EMOJI_FILE, 'r') { |f| YAML.load(f) }

  def emoji?
    return true if self =~ /^<:.+:\d+>$/
    EMOJI_LIST.include?(self.delete("\uFE0F"))
  end
end
