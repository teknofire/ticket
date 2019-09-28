require 'helpers/config'
require 'zendesk_api'

module Ticket
  class Actions
    def self.client
      @client ||= ZendeskAPI::Client.new do |config|
        # Mandatory:

        config.url = Ticket.config.zendesk_url # e.g. https://mydesk.zendesk.com/api/v2

        # Basic / Token Authentication
        config.username = Ticket.config.zendesk_user

        # Choose one of the following depending on your authentication choice
        config.token = Ticket.config.zendesk_token
        # config.password = "your zendesk password"

        # OAuth Authentication
        # config.access_token = "your OAuth access token"

        # Optional:

        # Retry uses middleware to notify the user
        # when hitting the rate limit, sleep automatically,
        # then retry the request.
        config.retry = true

        # Raise error when hitting the rate limit.
        # This is ignored and always set to false when `retry` is enabled.
        # Disabled by default.
        config.raise_error_when_rate_limited = false

        # Logger prints to STDERR by default, to e.g. print to stdout:
        require 'logger'
        config.logger = Logger.new(File.expand_path(Ticket.config.logfile))

        # Changes Faraday adapter
        # config.adapter = :patron

        # Merged with the default client options hash
        # config.client_options = {:ssl => {:verify => false}}

        # When getting the error 'hostname does not match the server certificate'
        # use the API at https://yoursubdomain.zendesk.com/api/v2
      end
    end

    def self.ticket(id)
      ZendeskAPI::Ticket.find(client, id: id)
    end

    def self.download(id, **opts)
      puts "Downloading attachments for ticket #{id}"
      ticket(id).comments.all do |comment|
        comment.attachments.each do |attachment|
          overwrite_message = ""
          if File.exist?(attachment.file_name)
            unless opts[:force]
              puts "Skipping #{attachment.file_name}, already exists..."
              next
            else
              overwrite_message = ", overwritting existing file"
            end
          end

          wget_options = []
          wget_options << '--quiet' unless opts[:verbose]
          wget_options << "-O #{attachment.file_name}"

          puts "Downloading #{attachment.file_name}#{overwrite_message}"
          system "wget #{wget_options.join(' ')} '#{attachment.mapped_content_url}'"
        end
      end

    end
  end
end
