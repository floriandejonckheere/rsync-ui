# frozen_string_literal: true

module DateHelper
  def time_of_day(at: Time.zone.now)
    case at.hour
    when 6..8
      "morning"
    when 8..14
      "day"
    when 14..18
      "afternoon"
    when 18..22
      "evening"
    else
      "night"
    end
  end
end
