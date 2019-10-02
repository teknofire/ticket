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

      def combine_files(input_files = nil, **opts)
        if input_files.nil? || input_files.empty?
          puts "Looking for split files..."
          combos = find_files
        else
          combos = combination_for input_files
        end

        combos.each do |combo, files|
          puts '-'*40
          puts "Detected split files for " + "#{combo}".yellow
          cmd = ['cat', files.sort, '>', combo]

          puts "Combining #{files.count.to_s.yellow} files into #{combo.yellow}"

          if File.exist?(combo)
            next if !opts[:force] && prompt.no?("Output #{combo.yellow} already exists, overwrite?")
          else
            next unless opts[:force] || prompt.yes?("Proceed?")
          end

          system(cmd.join(' '))
          puts "Created #{combo.yellow}"
        end
      end

      protected

      def find_files
        check_for = [
          ['*.part*'],
          ['*.[0-9a-z][0-9a-z]'],
          ['*-[a-z][a-z]', '-']
        ]
        check_for.inject({}) do |collection,opts|
          files = combination_for(Dir.glob(opts.shift), opts.shift)
          collection.merge! files unless files.keys.empty?
          collection
        end
      end

      def check_extension(file)
        return nil if file.empty?
        if File.fnmatch('*.tar.gz', file)
          file
        else
          "#{file}.tar.gz"
        end
      end

      def combination_for(files, split = '.')
        return {} if files.empty?

        files.uniq.inject({}) do |collection, file|
          return collection if File.fnmatch?('.gz', file)

          parts = file.split(split)
          parts.pop #discard the extention

          combo = check_extension(parts.join(split))
          return collection if combo.nil?

          collection[combo] ||= []
          collection[combo] << file unless collection[combo].include?(file)
          collection
        end
      end
    end
  end
end
