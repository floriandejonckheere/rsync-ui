# frozen_string_literal: true

class FlushService
  attr_reader :interval,
              :entries,
              :last_called_at

  def initialize(interval:)
    @interval = interval
    @entries = []
    @last_called_at = nil
  end

  def call(entry = nil, force: false)
    entries << entry unless entry.nil?

    return if entries.blank?
    return if !force && last_called_at.present? && (last_called_at + interval).future?

    yield entries

    @entries = []
    @last_called_at = Time.current
  end
end
