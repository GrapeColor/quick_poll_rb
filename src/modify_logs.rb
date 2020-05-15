# frozen_string_literal: true

require 'yaml'

class Discordrb::Logger
  IGNORE_FILE = File.expand_path('../ignore_logs.yml', __FILE__)
  IGNORE_LIST = File.open(IGNORE_FILE, 'r') { |f| YAML.load(f) }.join('|')

  private
  alias_method :_write, :write

  def write(message, mode)
    return if message =~ /(#{IGNORE_LIST})/
    self.mode = :debug if message =~ /\] Code: 1000/
    _write(message, mode)
  end
end
