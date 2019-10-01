require "tty-prompt"
require 'zendesk_api'

module CommonHelpers
  def prompt
    TTY::Prompt.new
  end

  def zendesk_enabled?
    Ticket.config.zendesk_token && Ticket.config.zendesk_user
  end

  def zendesk_client
    @zendesk_client ||= ZendeskAPI::Client.new do |config|
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

  def fetch_zendesk_ticket(id)
    return nil unless zendesk_enabled?

    ZendeskAPI::Ticket.find(zendesk_client, id: id)
  end
end
