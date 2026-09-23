# frozen_string_literal: true

class Category < ApplicationRecord
  CATEGORIZABLE_TYPES = [
    "Job",
    "Repository",
    "Server",
  ].freeze

  belongs_to :user

  normalizes :name,
             with: ->(name) { name.strip }

  validates :name,
            presence: true,
            uniqueness: { scope: [:user_id, :categorizable_type], case_sensitive: false }

  validates :categorizable_type,
            inclusion: { in: CATEGORIZABLE_TYPES }

  scope :named,
        ->(name) { where("LOWER(#{quoted_table_name}.name) = LOWER(?)", name.to_s.strip) }

  # Records of the categorizable type assigned to this category
  def records
    categorizable_type.constantize.where(category: self)
  end
end

# == Schema Information
#
# Table name: categories
#
#  id                 :uuid             not null, primary key
#  categorizable_type :string           not null
#  name               :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  user_id            :uuid             not null, indexed
#
# Indexes
#
#  index_categories_on_user_id                                  (user_id)
#  index_categories_on_user_id_and_categorizable_type_and_name  (user_id, categorizable_type, lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
