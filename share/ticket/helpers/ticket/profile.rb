# frozen_string_literal: true

module Ticket
  module Profile
    class Base
      attr_reader :max_summary_items

      def initialize(detailed, max_summary_items = 10)
        @detailed = detailed
        @max_summary_items = max_summary_items
      end

      protected

      def split(line)
        line.scan(/"[^"]+"|\[[^\]]+\]|\S+/).map { |s| s.delete('"') }.flatten.compact
      end

      def detailed?
        !!@detailed
      end

      def add_request_size(size)
        request_size << size
      end

      def stats
        @stats ||= {}
      end

      def request_size
        @request_size ||= []
      end

      def add_stat(group, first, second = nil, value = 1)
        return if first.nil?
        return if first.empty?

        stats[group] ||= {}

        if second.nil?
          stats[group][first] ||= 0
          stats[group][first] += value
        else
          stats[group][first] ||= {}
          stats[group][first]["__total__"] ||= 0
          stats[group][first]["__total__"] += value
          stats[group][first][second] ||= 0
          stats[group][first][second] += value
        end
      end

      def summarize(title, data, item = nil, max_key = 0)
        return unless item.nil? || data.key?(item)

        stats = !item.nil? ? data.dig(item) : data
        return if stats.keys.empty?

        total = stats.reject { |k, _v| k == "__total__" }.values.sum.to_f

        current_stats = stats.sort_by { |k, v| [-v, k] }[0...max_summary_items]

        max_key += current_stats.map { |k, _v| k.length }.max
        format = "%#{max_key}s: %7.3f%% (%i)"

        unless title.nil?
          puts "\n#{title} (Total: #{stats.keys.count})".green
          puts "-" * 80
        end

        current_stats.each do |key, value|
          next if key == "__total__"

          percent = value.to_f / total * 100
          puts format(format, key, percent, value)
        end

        if stats.key?("__total__")
          puts "-" * 40
          puts format(format, "Total", 100, stats["__total__"])
        end
      end

      def summarize_multi(title, data, item = nil)
        return unless item.nil? || data.key?(item)

        stats = !item.nil? ? data.dig(item) : data
        return if stats.keys.empty?

        total = stats.map { |_k, v| v["__total__"] }.sum.to_f

        puts "\n#{title} (Total: #{stats.keys.count})".green
        puts "=" * 80

        current_stats = stats.sort_by { |k, v| [-v["__total__"], k] }[0...max_summary_items]
        current_stats.each do |key, values|
          percent = values["__total__"].to_f / total * 100
          puts format("%s - %0.3f%% (%i)", key, percent, values["__total__"])
          puts "-" * 40
          summarize(nil, values)
          puts
        end
      end

      def summarize_request_size
        puts "\nRequest size (Total: #{Filesize.from("#{request_size.sum} B").pretty})".green
        puts "-" * 80

        format = "%16s: %s"
        stats = DescriptiveStatistics::Stats.new(request_size.sort)

        puts format(format, "Min size", Filesize.from("#{stats.min} B").pretty)
        puts format(format, "Max size", Filesize.from("#{stats.max} B").pretty)
        puts format(format, "Mean size", Filesize.from("#{stats.mean} B").pretty)

        (50..90).step(10).each do |i|
          size = Filesize.from(stats.value_from_percentile(i).to_s)
          puts format(format, "#{i}th percentile", size.pretty)
        end
        (95..99).each do |i|
          size = Filesize.from(stats.value_from_percentile(i).to_s)
          puts format(format, "#{i}th percentile", size.pretty)
        end
      end
    end
  end
end
