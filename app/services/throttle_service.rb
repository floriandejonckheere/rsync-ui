# frozen_string_literal: true

# Calls the given block at most once per interval, dropping any calls in between.
class ThrottleService
  attr_reader :interval,
              :last_called_at

  def initialize(interval:)
    @interval = interval
    @last_called_at = nil
  end

  def call
    return if last_called_at.present? && (last_called_at + interval).future?

    @last_called_at = Time.current

    yield
  end
end
