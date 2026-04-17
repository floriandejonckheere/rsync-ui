# frozen_string_literal: true

module Discard
  extend ActiveSupport::Concern

  included do
    class_attribute :discard_column_name,
                    default: :discarded_at

    scope :kept, -> { where(discard_column_name => nil) }
    scope :discarded, -> { where.not(discard_column_name => nil) }
  end

  class_methods do
    def discard_column(name)
      self.discard_column_name = name.to_sym
    end
  end

  def discarded?
    self[self.class.discard_column_name].present?
  end

  def kept?
    !discarded?
  end

  def discard!(time = Time.zone.now)
    return if discarded?

    update!(self.class.discard_column_name => time)
  end

  def restore!
    return unless discarded?

    update!(self.class.discard_column_name => nil)
  end
end
