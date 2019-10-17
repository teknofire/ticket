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
            download_file = attachment.file_name.gsub(/[\[\]()\s]+/, '_')
            if File.exist?(download_file)
              unless opts[:force]
                puts "Skipping #{download_file}, already exists..."
                next
              else
                overwrite_message = ", overwritting existing file"
              end
            end

            wget_options = []
            wget_options << '--quiet' unless opts[:verbose]
            wget_options << "-O \"#{download_file}\""

            puts "Downloading #{download_file}#{overwrite_message}"
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
          ['*.[0-9][0-9]'],
          ['*.[a-z][a-z]'],
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
        elsif File.fnmatch('*.tar.gz.part', file)
          file.gsub('.part', '')
        else
          "#{file}.tar.gz"
        end
      end

      def combination_for(files, split = '.')
        return {} if files.empty?

        split ||= '.'
        files.sort.uniq.inject({}) do |collection, file|
          return collection if File.fnmatch?('*.gz', file)

          parts = file.split(split)
          parts.pop #discard the extention
          combo = check_extension(parts.join(split))

          unless combo.nil?
            collection[combo] ||= []
            collection[combo] << file unless collection[combo].include?(file)
          end

          collection
        end
      end
    end
  end
end
