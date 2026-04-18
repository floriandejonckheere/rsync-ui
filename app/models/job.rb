# frozen_string_literal: true

class Job < ApplicationRecord
  belongs_to :user

  belongs_to :source_repository,
             class_name: "Repository"

  belongs_to :destination_repository,
             class_name: "Repository"

  validates :name,
            presence: true

  validate :different_repositories
  validate :destination_repository_writable
  validate :valid_schedule

  private

  def different_repositories
    return if source_repository.blank? || destination_repository.blank?
    return if source_repository != destination_repository

    errors.add(:destination_repository, :same_as_source)
  end

  def destination_repository_writable
    return if destination_repository.blank? || !destination_repository.read_only?

    errors.add(:destination_repository, :read_only)
  end

  def valid_schedule
    return if schedule.blank?
    return if Fugit.parse_cron(schedule).present?

    errors.add(:schedule, :invalid)
  rescue StandardError
    errors.add(:schedule, :invalid)
  end
end

# == Schema Information
#
# Table name: jobs
#
#  id                        :uuid             not null, primary key
#  description               :text
#  enabled                   :boolean          default(TRUE), not null
#  name                      :string           not null
#  schedule                  :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  destination_repository_id :uuid             not null, indexed
#  source_repository_id      :uuid             not null, indexed
#  user_id                   :uuid             not null, indexed
#
# Indexes
#
#  index_jobs_on_destination_repository_id  (destination_repository_id)
#  index_jobs_on_source_repository_id       (source_repository_id)
#  index_jobs_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (destination_repository_id => repositories.id)
#  fk_rails_...  (source_repository_id => repositories.id)
#  fk_rails_...  (user_id => users.id)
#
