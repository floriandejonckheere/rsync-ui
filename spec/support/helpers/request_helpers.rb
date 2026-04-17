# frozen_string_literal: true

module RequestHelpers
  def response_body
    text = []

    Nokogiri::HTML(response.body)
      .traverse { |x| text << x.text if x.text? && x.text !~ /^\s*$/ }

    text.join(" ")
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end
