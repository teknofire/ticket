# frozen_string_literal: true

require 'fileutils'
require 'helpers/ticket/config'
require 'helpers/actions'
require 'helpers/common'

module Ticket
  class Info
    include CommonHelpers

    attr_reader :id, :client

    def initialize(id = nil, client = nil)
      file = find_local_ticket_info
      if file.nil? && !id.nil?
        @id = id
        file = self.class.info_file_path(id)
      end

      @client = client unless client.nil?

      if File.exist?(file)
        @info = JSON.parse(File.read(file))

        # load data from ticket.info file
        @id ||= @info['id']
        @client ||= @info['client']
      end
    end

    def find_local_ticket_info
      %w[ticket.info ../ticket.info].each do |file|
        return file if File.exist?(File.expand_path(file))
      end
      nil
    end

    def url
      "https://getchef.zendesk.com/agent/tickets/#{id}"
    end

    def status
      zendesk.status
    end

    def zendesk
      @zendesk ||= fetch_zendesk_ticket(@id)
    end

    def to_s
      "#{client.capitalize} - #{id}"
    end

    def summary
      "#{client.capitalize} - #{id} (#{status})"
    end

    def full_path
      @full_path ||= self.class.full_path(client, id)
    end

    def path
      @path ||= self.class.path(id)
    end

    def info_file_path
      @info_file_path ||= self.class.info_file_path(id)
    end

    def symlink
      @symlink ||= self.class.ticket_symlink(id)
    end

    def delete(**opts)
      if opts[:yes] || prompt.yes?("Delete ticket #{summary}?")
        prompt.say "\u{2716}".red + " Deleting #{summary}"
      else
        prompt.say "Skipping #{summary}".yellow
        return
      end

      # RM ticket info/downloads and clean up symlink
      FileUtils.rm_rf full_path
      FileUtils.rm symlink
    end

    def save
      FileUtils.mkdir_p(full_path)

      return unless File.directory?(full_path)

      FileUtils.ln_sf(full_path, symlink)

      File.open(info_file_path, 'w') do |fp|
        fp << JSON.pretty_generate(id: id, client: client)
      end
    end

    class << self
      def load(id)
        new(id)
      end

      def config
        Ticket.config
      end

      def full_path(client, id)
        File.join(client_path(client), id)
      end

      def path(id)
        dir = ticket_symlink(id)
        if File.exist?(dir)
          File.realpath(dir)
        else
          dir
        end
      end

      def exists?(id)
        File.exist?(info_file_path(id))
      end

      def info_file_path(id)
        path = File.join(path(id), 'ticket.info')
        if File.exist?(path)
          File.realpath(path)
        else
          path
        end
      end

      def ticket_symlink(id = nil)
        params = [config.ticket_path, '.tickets']
        FileUtils.mkdir_p File.join(params)
        params << id unless id.nil?
        File.join(params)
      end

      def clients
        Dir.entries(config.ticket_path).reject { |file| file[0] == '.' }
      end

      def client_path(client)
        File.join(config.ticket_path, client)
      end

      def all(client = nil)
        ids(client).map { |id| new(id) }
      end

      def empty?(client = nil)
        ids(client).empty?
      end

      def ids(client = nil)
        if client.nil?
          Dir.entries(ticket_symlink).reject { |file| file[0] == '.' }
        else
          Dir.entries(client_path(client)).reject { |file| file[0] == '.' }
        end
      end
    end
  end
end
