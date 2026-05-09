# frozen_string_literal: true

module JobRunHelper
  def relative_time_tag(timestamp)
    tag.time(title: timestamp.iso8601, datetime: timestamp.iso8601) do
      relative_time_in_words(timestamp)
    end
  end
end
