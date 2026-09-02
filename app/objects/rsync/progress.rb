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
                :remaining_time_approximate,
                :files_transferred,
                :files_checked,
                :files_total

    alias remaining_time_approximate? remaining_time_approximate

    # `aggregate: true` marks the whole line stream as coming from --info=progress2, which
    # alternates between two line shapes for the *same* aggregate counters: intermediate
    # ticks (no `(xfr#N, to-chk=X/Y)` suffix, time field is a real ETA) and end-of-file ticks
    # (suffix present, time field is elapsed time instead). Trusting rsync's own field on one
    # shape and computing it on the other produces two disagreeing numbers that flicker in the
    # UI, so when aggregate is true we always compute remaining_time ourselves for consistency,
    # regardless of which shape a given line happens to be.
    def initialize(line, aggregate: false)
      match = PATTERN.match(line)

      return unless match

      @bytes = parse_bytes(match[:bytes])
      @progress = match[:progress].to_i
      @speed = parse_speed(match[:speed])
      @files_transferred = match[:files_transferred]&.to_i
      @files_checked = match[:files_checked]&.to_i
      @files_total = match[:files_total]&.to_i

      @remaining_time_approximate = aggregate || @files_transferred.present?
      @remaining_time = @remaining_time_approximate ? estimate_remaining_time : parse_time(match[:remaining_time])
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

    def parse_time(value)
      value
        .split(":")
        .map(&:to_i)
        .reverse
        .each_with_index
        .sum { |v, i| v * (60**i) }
    end

    # Estimates remaining time for a --info=progress2 line from the bytes transferred so
    # far and the overall percentage, since rsync's own time field is elapsed time here.
    def estimate_remaining_time
      return nil if progress.zero? || speed.zero?

      ((bytes.to_f / progress) * (100 - progress) / speed).round
    end
  end
end
