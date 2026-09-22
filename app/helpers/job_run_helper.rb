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

    if h.positive?
      "#{h}h #{m}m #{s}s"
    elsif m.positive?
      "#{m}m #{s}s"
    else
      "#{s}s"
    end
  end

  def format_remaining_time(seconds, approximate: false)
    return unless seconds

    return "< 1 min" if seconds < 60

    h = seconds / 3600
    m = (seconds % 3600) / 60
    formatted = h.positive? ? "#{h}h #{m}m" : "#{m}m"

    "#{'~' if approximate}#{formatted}"
  end
end
