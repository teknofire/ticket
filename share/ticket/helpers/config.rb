require 'tty-config'

module Ticket
  def self.config
    @config ||= Config.new
  end

  class Config
    attr_accessor :config

    def initialize
      @config = TTY::Config.new
      @config.filename = 'ticket'
      @config.extname = '.toml'
      @config.append_path Dir.pwd
      @config.append_path File.join(Dir.home, '.support')
      @config.read
    end

    def zendesk_url
      @config.fetch('zendesk_url')
    end

    def zendesk_user
      @config.fetch('zendesk_user')
    end

    def zendesk_token
      @config.fetch('zendesk_token')
    end

    def logfile
      @config.fetch('logfile')
    end
  end
end
