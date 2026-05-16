# frozen_string_literal: true

module Servers
  module ResourceUsage
    class LinuxService < BaseService
      CPU_PATTERN = /^%Cpu\(s\):\s+[\d.]+\s+us.*?\s+([\d.]+)\s+id/
      CPU_PATTERN_BSD = /^CPU:\s+[\d.]+%\s+usr.*?\s+([\d.]+)%\s+idle/

      protected

      def command
        path = Shellwords.escape(server.path.presence || "/")
        <<~BASH.gsub('"$TARGET_PATH"', path)
          echo "---CPU---"
          nproc
          top -bn2 -d1 | grep -i '^%\\?Cpu' | tail -1
          echo "---MEM---"
          cat /proc/meminfo
          echo "---UPTIME---"
          cat /proc/uptime
          cat /proc/loadavg
          echo "---DISK---"
          df -PB1 "$TARGET_PATH"
        BASH
      end

      private

      def parse(output)
        sections = split_sections(output)
        raise "missing probe sections" unless sections.key?("DISK")

        result = parse_disk(sections.fetch("DISK"))
        result.merge!(parse_cpu(sections.fetch("CPU"))) if sections.key?("CPU")
        result.merge!(parse_mem(sections.fetch("MEM"))) if sections.key?("MEM")
        result.merge!(parse_uptime(sections.fetch("UPTIME"))) if sections.key?("UPTIME")
        result
      end

      def parse_cpu(text)
        lines = text.lines.map(&:strip).reject(&:empty?)
        cpu_count = Integer(lines.shift)

        m = lines.first&.match(CPU_PATTERN) || lines.first&.match(CPU_PATTERN_BSD)
        raise "cpu sample missing" unless m

        { cpu_count:, cpu_usage: (100.0 - m[1].to_f).round(2) }
      end
    end
  end
end
