# frozen_string_literal: true

require "helpers/ticket/profile"

module Ticket
  module Profile
    class AutomateLB < Ticket::Profile::Base
      def add(line)
        return unless line.match?(/automate-load-balancer.default/)

        log_parts = request_components(line)

        add_request_size(log_parts[:request_size])

        add_stat("agents", log_parts[:agent])
        add_stat("status", log_parts[:status])
        if detailed?
          add_stat("methods_status", log_parts[:method], log_parts[:status])
          add_stat("endpoints_status", log_parts[:endpoint], log_parts[:status])
        else
          add_stat("methods", log_parts[:method])
          add_stat("endpoints", log_parts[:endpoint])
        end
      end

      def display
        puts "" # left blank intentionally
        puts "Showing request stats for automate-load-balancer only".green
        puts "-" * 80

        summarize "HTTP Status", stats, "status"
        if detailed?
          summarize_multi "HTTP Method", stats, "methods_status"
          summarize_multi "HTTP Endpoints", stats, "endpoints_status"
        else
          summarize "HTTP Method", stats, "methods"
          summarize "HTTP Endpoints", stats, "endpoints"
        end
        summarize "Agents", stats, "agents"
        summarize_request_size
      end

      protected

      def request_components(line)
        log_parts = split(line)

        method, path, http_version = log_parts[8].split(" ")

        if path.nil?
          endpoint = "unknown"
        else
          uri = URI(File.join("http://localhost", path))
          path_parts = uri.path.split("/")
          path_parts.shift
          endpoint = path_parts.first
        end

        {
          request: log_parts[8],
          status: log_parts[9],
          request_time: log_parts[16],
          method: method,
          path: path,
          endpoint: endpoint,
          http_version: http_version,
          agent: log_parts[13].split(" ")[0..1].join(" "),
          client_name: log_parts[12],
          request_size: log_parts[17].to_i
        }
      end
    end
  end
end
