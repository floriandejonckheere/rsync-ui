# frozen_string_literal: true

module Duplicatable
  extend ActiveSupport::Concern

  included do
    class_attribute :duplication_associations,
                    default: []
  end

  class_methods do
    def inherited(subclass)
      super

      subclass.duplication_associations = duplication_associations.dup
    end

    def duplicates_associations(*associations)
      self.duplication_associations = associations
    end
  end

  def dup
    copy = super

    self.class.duplication_associations.each do |association|
      public_send(association).each { |record| copy.public_send(association) << record.dup }
    end

    copy
  end
end
