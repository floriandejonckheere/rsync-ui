# frozen_string_literal: true

class ApplicationError < StandardError
  attr_reader :key,
              :context

  def initialize(key, **context)
    @key = key
    @context = context

    super("#{title}: #{description}")
  end

  def title
    I18n.t("errors.#{key}.title")
  end

  def description
    I18n.t("errors.#{key}.description", **context)
  end
end
