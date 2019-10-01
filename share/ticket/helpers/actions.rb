require 'fileutils'
require 'helpers/ticket'
require 'helpers/ticket/config'

module Ticket
  class Actions
    class << self
      include CommonHelpers

      def download(id, **opts)
        puts "Downloading attachments for ticket #{id}"
        fetch_zendesk_ticket(id).comments.all do |comment|
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
end
