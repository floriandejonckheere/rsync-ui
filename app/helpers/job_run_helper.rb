# frozen_string_literal: true

module JobRunHelper
  def relative_time_tag(timestamp)
    tag.time(title: timestamp.iso8601, datetime: timestamp.iso8601) do
      relative_time_in_words(timestamp)
    end
  end

  def format_speed(bytes_per_sec)
    return unless bytes_per_sec

    if bytes_per_sec >= 1_000_000_000
      "#{format('%.0f', bytes_per_sec / 1_000_000_000.0)} GB/s"
    elsif bytes_per_sec >= 1_000_000
      "#{format('%.0f', bytes_per_sec / 1_000_000.0)} MB/s"
    elsif bytes_per_sec >= 1_000
      "#{format('%.0f', bytes_per_sec / 1_000.0)} kB/s"
    else
      "#{bytes_per_sec} B/s"
    end
  end

  def format_time(seconds)
    return unless seconds

    h = seconds / 3600
    m = (seconds % 3600) / 60
    s = seconds % 60

    h.positive? ? format("%<h>d:%<m>02d:%<s>02d", h:, m:, s:) : format("%<m>d:%<s>02d", m:, s:)
  end
end
