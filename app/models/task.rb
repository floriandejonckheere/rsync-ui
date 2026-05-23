# frozen_string_literal: true

class Task < ApplicationRecord
  belongs_to :last_run_by,
             class_name: "User",
             inverse_of: false,
             optional: true

  validates :name,
            presence: true,
            uniqueness: true

  validates :class_name,
            presence: true

  enum :status, {
    running: "running",
    completed: "completed",
    failed: "failed",
  }, validate: { allow_nil: true }

  def configuration_satisfied?
    return true if configuration.blank?

    Configuration
      .get(configuration)
      .present?
  end
end

# == Schema Information
#
# Table name: tasks
#
#  id             :uuid             not null, primary key
#  class_name     :string           not null
#  configuration  :string
#  error_class    :string
#  error_message  :text
#  last_run_at    :datetime
#  name           :string           not null, uniquely indexed
#  status         :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  last_run_by_id :uuid             indexed
#
# Indexes
#
#  index_tasks_on_last_run_by_id  (last_run_by_id)
#  index_tasks_on_name            (name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (last_run_by_id => users.id) ON DELETE => nullify
#
