# frozen_string_literal: true

module Rsync
  class Progress
    # Status line regexp
    PATTERN = %r(^\s*(?<bytes>[\d,.]+[BKMGT]?)\s+(?<progress>\d+)%\s+(?<speed>\S+)\s+(?<remaining_time>[\d:]+)(?:\s+\(xfr#(?<files_transferred>\d+),\s+(?:ir-chk|to-chk)=(?<files_checked>\d+)/(?<files_total>\d+)\))?)

    MULTIPLIERS = {
      "B" => 1,
      "K" => 1_000,
      "M" => 1_000**2,
      "G" => 1_000**3,
      "T" => 1_000**4,
      "P" => 1_000**5,
      "E" => 1_000**6,
    }.freeze

    attr_reader :bytes,
                :progress,
                :speed,
                :remaining_time,
                :files_transferred,
                :files_checked,
                :files_total

    def initialize(line)
      match = PATTERN.match(line)

      return unless match

      @bytes = parse_bytes(match[:bytes])
      @progress = match[:progress].to_i
      @speed = parse_speed(match[:speed])
      @remaining_time = parse_remaining_time(match[:remaining_time])
      @files_transferred = match[:files_transferred]&.to_i
      @files_checked = match[:files_checked]&.to_i
      @files_total = match[:files_total]&.to_i
    end

    private

    def parse_bytes(value)
      multiplier = MULTIPLIERS[value[-1].upcase]

      return (value.to_f * multiplier).to_i if multiplier

      value
        .delete(",")
        .to_i
    end

    def parse_speed(value)
      match = value.match(%r(^([\d.]+)(\w+)/s$))

      return 0 unless match

      multiplier = MULTIPLIERS[match[2][0].upcase] || 1

      (match[1].to_f * multiplier).to_i
    end

    def parse_remaining_time(value)
      value
        .split(":")
        .map(&:to_i)
        .reverse
        .each_with_index
        .sum { |v, i| v * (60**i) }
    end
  end
end
