# frozen_string_literal: true

require 'json'
require 'fileutils'

module TicketInfo
  def root
    ENV['TICKET_ROOT'] || File.join(ENV['HOME'], 'support')
  end

  def find_ticket(id)
    Ticket::Info.load(id)
  end

  def read_ticket_info(filename)
    return unless File.exist?(filename)

    JSON.parse(File.read(filename))
  end

  def find_local_ticket_info
    %w[ticket.info ../ticket.info].each do |file|
      return file if File.exist?(File.expand_path(file))
    end
    nil
  end

  def full_ticket_info_path(client, id)
    File.join(root, client, id, 'ticket.info')
  end

  def ticket_info_path(id)
    path = File.join(linked_ticket_path, id, 'ticket.info')
    if File.exist?(path)
      File.realpath(path)
    else
      path
    end
  end

  def linked_ticket_path(ticket_id = nil)
    params = [root, '.tickets']
    FileUtils.mkdir_p File.join(params)

    params << ticket_id if ticket_id
    File.join(params)
  end

  def ticket_url
    "https://getchef.zendesk.com/agent/tickets/#{ticket.id}"
  end

  def ticket_path
    File.dirname(ticket_info_path(ticket.id))
  end

  def client_list
    Dir.entries(root).reject { |file| file[0] == '.' }
  end

  def all_ticket_ids
    Dir.entries(linked_ticket_path).reject { |file| file[0] == '.' }
  end

  def ticket_ids(client)
    Dir.entries(File.join(root, client)).reject { |file| file[0] == '.' }
  end
end
