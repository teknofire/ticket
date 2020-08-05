# frozen_string_literal: true

require "tty-config"

module Ticket
  def self.config
    @config ||= Config.new
  end

  class Config
    attr_accessor :config

    def initialize
      @config = TTY::Config.new
      @config.filename = "ticket"
      @config.extname = ".toml"
      @config.append_path Dir.pwd
      @config.append_path File.join(Dir.home, ".support")
      @config.read
    end

    def ticket_path
      # support old config option with TICKET_ROOT env var
      File.expand_path(ENV["TICKET_ROOT"] || @config.fetch("ticket_path") || File.join(ENV["HOME"], "support"))
    end

    def zendesk_url
      @config.fetch("zendesk_url")
    end

    def zendesk_user
      @config.fetch("zendesk_user")
    end

    def zendesk_token
      @config.fetch("zendesk_token")
    end

    def zendesk?
      zendesk_url && zendesk_user && zendesk_token
    end

    def logfile
      @config.fetch("logfile")
    end

    def autodownload?
      !!@config.fetch("autodownload")
    end

    def open_browser?
      !!@config.fetch("open_browser")
    end

    def skip_new?
      !!@config.fetch("skip_new")
    end

    # Sendsafely related configuration
    def sendsafely_url
      @config.fetch("sendsafely_url")
    end
    def sendsafely_key_id
      sendsafely = @config.fetch("sendsafely_key_id")
      unless sendsafely.nil?
        return sendsafely
      else
        deprecated = @config.fetch("key_id")
        puts 'WARNING: You\'re using DEPRECATED "key_id" configuration setting in ticket.toml. Please use "sendsafely_key_id" instead.:'
        return deprecated
      end
    end
    def sendsafely_key_secret
      sendsafely = @config.fetch("sendsafely_key_secret")
      unless sendsafely.nil?
        return sendsafely
      else
        deprecated = @config.fetch("key_secret")
        puts 'WARNING: You\'re using DEPRECATED "key_secret" configuration setting in ticket.toml. Please use "sendsafely_key_secret" instead.'
        return deprecated
      end
    end

  end
end
