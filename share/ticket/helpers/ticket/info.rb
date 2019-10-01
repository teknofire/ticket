require 'fileutils'
require 'helpers/ticket/config'
require 'helpers/actions'
require 'helpers/common'

module Ticket
  class Info
    include CommonHelpers

    attr_reader :id, :client

    def initialize(id = nil)
      if id.nil?
        file = find_local_ticket_info
      else
        file = self.class.info_file_path(id)
      end

      unless File.exist?(file)
        raise NotFound, "Error: Could not find local ticket info\nExpected '#{file}' to exist"
      end

      @info = JSON.parse(File.read(file))

      @id = @info['id']
      @client = @info['client']
    end

    def find_local_ticket_info
      %w{ ticket.info ../ticket.info }.each do |file|
        return file if File.exists?(File.expand_path(file))
      end
      return nil
    end

    def info_file_path
      self.class.info_file_path(@id)
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
      "#{client.capitalize} - #{id} (#{status})"
    end

    def path
      self.class.path(@id)
    end

    def symlink
      self.class.ticket_symlink(@id)
    end

    def delete(**opts)
      if opts[:yes] || prompt.yes?("Delete ticket #{self}?")
        prompt.say "\u{2716}".red + " Deleting #{self}"
      else
        prompt.say "Skipping #{self}".yellow
        return
      end

      # RM ticket info/downloads and clean up symlink
      FileUtils.rm_rf path
      FileUtils.rm symlink
    end

    def save
      return unless File.directory?(path)
      FileUtils.ln_sf(path, symlink)
    end

    class << self
      def load(id)
        new(id)
      end

      def config
        Ticket.config
      end

      def path(id)
        dir = ticket_symlink(id)
        if File.exists?(dir)
          File.realpath(dir)
        else
          dir
        end
      end

      def exists?(id)
        File.exists?(info_file_path(id))
      end

      def info_file_path(id)
        path = File.join(path(id), 'ticket.info')
        if File.exists?(path)
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
