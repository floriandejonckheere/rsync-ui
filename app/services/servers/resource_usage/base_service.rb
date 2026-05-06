# frozen_string_literal: true

module Servers
  module ResourceUsage
    class BaseService < SSHService
      SECTION = /^---(\w+)---$/

      def call
        output = super
        metrics = parse(output)

        (server.resource_usage || server.build_resource_usage).update!(
          metrics.merge(
            status: "ok",
            error_class: nil,
            error_message: nil,
            probed_at: Time.current,
          ),
        )
      rescue StandardError => e
        (server.resource_usage || server.build_resource_usage).update!(
          status: "failed",
          error_class: e.class,
          error_message: e.message,
          probed_at: Time.current,
        )
      end

      private

      def parse(_output)
        raise NotImplementedError
      end

      def split_sections(output)
        current = nil

        output.each_line.with_object({}) do |line, acc|
          if (m = line.match(SECTION))
            current = m[1]
            acc[current] = []
          elsif current
            acc[current] << line
          end
        end.transform_values(&:join)
      end

      def parse_disk(text)
        lines = text.lines
        header = lines.find { |l| l.start_with?("Filesystem") }
        multiplier = header&.include?("1K-blocks") ? 1024 : 1

        data_line = lines.find do |l|
          next false if l.start_with?("Filesystem")

          parts = l.split
          parts.size >= 5 && parts[1].match?(/\A\d+\z/)
        end

        raise "no df output" unless data_line

        parts = data_line.split

        {
          disk_total: parts[1].to_i * multiplier,
          disk_used: parts[2].to_i * multiplier,
        }
      end

      def parse_mem(text)
        fields = text.lines.each_with_object({}) do |l, h|
          k, v = l.split(":", 2)
          h[k] = v.to_s.strip.split.first.to_i * 1024 if v
        end

        total = fields.fetch("MemTotal")
        available = fields.fetch("MemAvailable")

        {
          memory_total: total,
          memory_used: total - available,
        }
      end

      def parse_uptime(text)
        lines = text.lines.map(&:strip).reject(&:empty?)
        uptime = lines[0].split.first.to_f.to_i
        load_parts = lines[1].split

        {
          uptime_seconds: uptime,
          load_avg_1: load_parts[0].to_f,
          load_avg_5: load_parts[1].to_f,
          load_avg_15: load_parts[2].to_f,
        }
      end
    end
  end
end
