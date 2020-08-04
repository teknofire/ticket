# frozen_string_literal: true

require "fileutils"
require 'uri'
require "helpers/ticket"
require "helpers/ticket/config"
require 'lib/sendsafely'

module Ticket
  class Actions
    class << self
      include CommonHelpers

      def download(id, **opts)
        puts "Downloading attachments for ticket #{id}"
        zdticket = fetch_zendesk_ticket(id)

        if zdticket.nil?
          puts "Unable to find Zendesk Ticket ##{id}"
          return
        end

        # Initialize Sendsafely from configuration
        @sendsafely = Sendsafely.new(Ticket.config, **opts)

        zdticket.comments.all do |comment|
          #
          # Downloading ticket attachments - old method of sharing links
          comment.attachments.each do |attachment|
            overwrite_message = ""
            download_file = attachment.file_name.gsub(/[\[\]()\s]+/, "_")
            if File.exist?(download_file)
              if opts[:force]
                overwrite_message = ", overwritting existing file"
              else
                puts "Skipping #{download_file}, already exists..."
                next
              end
            end

            wget_options = []
            wget_options << "--quiet" unless opts[:verbose]
            wget_options << "-O \"#{download_file}\""

            puts "Downloading #{download_file}#{overwrite_message}"
            system "wget #{wget_options.join(' ')} '#{attachment.mapped_content_url}'"
          end

          #
          # Check content of comment for SendSafely download links
          downloads =  URI.extract(comment.body, /https/).filter { |link| link =~ /secure.chef.io\/receive/ }.uniq
          next if downloads.empty?

          puts "Downloading #{downloads.inspect}" if opts[:verbose]
          downloads.each do |link|
            @sendsafely.download_package(link)
          end
        end
      end

      def combine_files(input_files = nil, **opts)
        if input_files.nil? || input_files.empty?
          puts "Looking for split files..."
          combos = find_files
        else
          combos = combination_for input_files
        end

        combos.each do |combo, files|
          puts "-" * 40
          puts "Detected split files for " + combo.to_s.yellow
          cmd = ["cat", files.sort, ">", combo]

          puts "Combining #{files.count.to_s.yellow} files into #{combo.yellow}"

          if File.exist?(combo)
            if !opts[:force] && prompt.no?("Output #{combo.yellow} already exists, overwrite?")
              next
            end
          else
            next unless opts[:force] || prompt.yes?("Proceed?")
          end

          system(cmd.join(" "))
          puts "Created #{combo.yellow}"
        end
      end

      protected

      def find_files
        check_for = [
          ["*.part*"],
          ["*.[0-9][0-9]"],
          ["*.[a-z][a-z]"],
          ["*-[a-z][a-z]", "-"]
        ]
        check_for.each_with_object({}) do |opts, collection|
          files = combination_for(Dir.glob(opts.shift), opts.shift)
          collection.merge! files unless files.keys.empty?
        end
      end

      def check_extension(file)
        return nil if file.empty?

        if File.fnmatch("*.tar.gz", file)
          file
        elsif File.fnmatch("*.tar.gz.part", file)
          file.gsub(".part", "")
        else
          "#{file}.tar.gz"
        end
      end

      def combination_for(files, split = ".")
        return {} if files.empty?

        split ||= "."
        files.sort.uniq.each_with_object({}) do |file, collection|
          return collection if File.fnmatch?("*.gz", file)

          parts = file.split(split)
          parts.pop # discard the extention
          combo = check_extension(parts.join(split))

          unless combo.nil?
            collection[combo] ||= []
            collection[combo] << file unless collection[combo].include?(file)
          end
        end
      end
    end
  end
end
