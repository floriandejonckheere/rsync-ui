# frozen_string_literal: true

module Servers
  class ResourceUsageService < SSHService
    attr_reader :force

    def initialize(server, force: false)
      super(server)

      @force = force
    end

    def call
      probed_at = server.resource_usage&.probed_at

      return if probed_at && probed_at > 5.minutes.ago && !force

      output = super

      metrics = Parser.new(output).call

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

    SCRIPTS = {
      "linux" => Rails.root.join("lib/scripts/resource_usage_linux.sh"),
      "macos" => Rails.root.join("lib/scripts/resource_usage_macos.sh"),
      "hetzner" => Rails.root.join("lib/scripts/resource_usage_hetzner.sh"),
    }.freeze

    protected

    def command
      path = Shellwords.escape(server.path.presence || "/")
      script = SCRIPTS.fetch(server.operating_system).read

      "TARGET_PATH=#{path}\n#{script}"
    end

    class Parser
      SECTION = /^---(\w+)---$/
      MACOS_CPU_PATTERN = /CPU usage:\s*([\d.]+)%\s*user.*?([\d.]+)%\s*idle/

      def initialize(output)
        @output = output
      end

      def call
        sections = split_sections

        raise "missing probe sections" unless sections.key?("DISK")

        result = parse_disk(sections.fetch("DISK"))
        result.merge!(parse_cpu(sections.fetch("CPU"))) if sections.key?("CPU")
        result.merge!(parse_mem(sections.fetch("MEM"))) if sections.key?("MEM")
        result.merge!(parse_uptime(sections.fetch("UPTIME"))) if sections.key?("UPTIME")
        result
      end

      private

      attr_reader :output

      def split_sections
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

      def parse_cpu(text)
        lines = text.lines.map(&:strip).reject(&:empty?)
        cpu_count = Integer(lines.shift)

        if (m = lines.first&.match(MACOS_CPU_PATTERN))
          usage = (100.0 - m[2].to_f).round(2)
          return { cpu_count:, cpu_usage: usage }
        end

        samples = lines.first(2).map { |l| l.split[1..].map(&:to_i) }

        raise "cpu sample missing" if samples.size < 2

        idle1 = samples[0][3] + samples[0].fetch(4, 0)
        idle2 = samples[1][3] + samples[1].fetch(4, 0)
        total1 = samples[0].sum
        total2 = samples[1].sum
        total_delta = total2 - total1
        idle_delta = idle2 - idle1
        usage = total_delta.positive? ? ((1 - (idle_delta.to_f / total_delta)) * 100).round(2) : 0.0

        {
          cpu_count:,
          cpu_usage: usage,
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
        # rubocop:enable Naming/VariableNumber
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
    end
  end
end
