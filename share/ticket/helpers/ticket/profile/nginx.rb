# frozen_string_literal: true

require "helpers/ticket/profile"

module Ticket
  module Profile
    class Nginx < Ticket::Profile::Base
      def add(line)
        # puts log_parts.inspect
        log_parts = request_components(line)

        uri = URI(File.join("http://localhost", log_parts[:path]))
        if uri.path.nil?
          endpoint = "unknown"
        else
          path_parts = uri.path.split("/")
          if path_parts[1] == "organizations"
            endpoint = path_parts[3]
            org = path_parts[2]
          else
            endpoint = path_parts.first
          end
        end

        add_request_size(log_parts[:request_size])

        add_stat("agents", log_parts[:agent])
        add_stat("status", log_parts[:status])
        add_stat("orgs", org)
        if detailed?
          add_stat("methods_status", log_parts[:method], log_parts[:status])
          add_stat("endpoints_status", endpoint, log_parts[:status])
          add_stat("clients_status", log_parts[:client_name], log_parts[:status])
        else
          add_stat("methods", log_parts[:method])
          add_stat("endpoints", endpoint)
          add_stat("clients", log_parts[:client_name])
        end
      end

      def display
        summarize "Orgs", stats, "orgs"
        summarize "HTTP Status", stats, "status"
        if detailed?
          summarize_multi "HTTP Method", stats, "methods_status"
          summarize_multi "HTTP Endpoints", stats, "endpoints_status"
        else
          summarize "HTTP Method", stats, "methods"
          summarize "HTTP Endpoints", stats, "endpoints"
        end
        summarize "Agents", stats, "agents"
        if detailed?
          summarize_multi "Client Names", stats, "clients_status"
        else
          summarize "Client Names", stats, "clients"
        end
        summarize_request_size
      end

      protected

      def split(line)
        line.scan(/"[^"]+"|\[[^\]]+\]|\S+/).map { |s| s.delete('"') }.flatten.compact
      end

      def request_components(line)
        log_parts = split(line)

        method, path, http_version = log_parts[4].split(" ")

        {
          request: log_parts[4],
          status: log_parts[5],
          method: method,
          path: path,
          http_version: http_version,
          agent: log_parts[9].split(" ")[0..1].join(" "),
          client_name: log_parts[15],
          request_size: log_parts[18].to_i
        }
      end
    end
  end
end
