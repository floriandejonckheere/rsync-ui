# frozen_string_literal: true

class Job < ApplicationRecord
  belongs_to :user

  belongs_to :source_repository,
             class_name: "Repository"

  belongs_to :destination_repository,
             class_name: "Repository"

  has_many :job_runs,
           dependent: :destroy

  has_many :job_notifications,
           dependent: :destroy

  has_many :notifications,
           through: :job_notifications

  has_many :hooks,
           dependent: :destroy

  has_one :pre_hook,
          -> { where(hook_type: "pre") },
          class_name: "Hook",
          dependent: :destroy,
          inverse_of: :job

  has_one :post_hook,
          -> { where(hook_type: "post") },
          class_name: "Hook",
          dependent: :destroy,
          inverse_of: :job

  has_one :success_hook,
          -> { where(hook_type: "success") },
          class_name: "Hook",
          dependent: :destroy,
          inverse_of: :job

  has_one :failure_hook,
          -> { where(hook_type: "failure") },
          class_name: "Hook",
          dependent: :destroy,
          inverse_of: :job

  accepts_nested_attributes_for :job_notifications,
                                allow_destroy: true

  accepts_nested_attributes_for :hooks,
                                allow_destroy: true,
                                reject_if: proc { |attrs| attrs["command"].blank? }

  validates :name,
            presence: true

  validate :validate_different_repositories
  validate :validate_not_both_remote
  validate :validate_destination_repository_writable
  validate :validate_schedule

  def scheduled_next_run
    return unless enabled? && schedule.present?

    Fugit
      .parse_cron(schedule)
      &.next_time(Time.zone.now)
      &.to_t
  end

  private

  def validate_different_repositories
    return if source_repository.blank? || destination_repository.blank?
    return if source_repository != destination_repository

    errors.add(:destination_repository, :same_as_source)
  end

  def validate_not_both_remote
    return if source_repository.blank? || destination_repository.blank?
    return unless source_repository.remote? && destination_repository.remote?

    errors.add(:base, :not_both_remote)
  end

  def validate_destination_repository_writable
    return if destination_repository.blank? || !destination_repository.read_only?

    errors.add(:destination_repository, :read_only)
  end

  def validate_schedule
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
#  description               :text             indexed
#  enabled                   :boolean          default(TRUE), not null
#  name                      :string           not null, indexed, indexed
#  opt_acls                  :boolean          default(FALSE), not null
#  opt_append                :boolean          default(FALSE), not null
#  opt_archive               :boolean          default(FALSE), not null
#  opt_arguments             :text
#  opt_backup                :boolean          default(FALSE), not null
#  opt_checksum              :boolean          default(FALSE), not null
#  opt_compress              :boolean          default(FALSE), not null
#  opt_delete                :boolean          default(FALSE), not null
#  opt_delete_excluded       :boolean          default(FALSE), not null
#  opt_devices               :boolean          default(FALSE), not null
#  opt_dry_run               :boolean          default(FALSE), not null
#  opt_exclude               :text             default([]), not null, is an Array
#  opt_existing              :boolean          default(FALSE), not null
#  opt_group                 :boolean          default(FALSE), not null
#  opt_hard_links            :boolean          default(FALSE), not null
#  opt_ignore_existing       :boolean          default(FALSE), not null
#  opt_include               :text             default([]), not null, is an Array
#  opt_inplace               :boolean          default(FALSE), not null
#  opt_itemize_changes       :boolean          default(FALSE), not null
#  opt_links                 :boolean          default(TRUE), not null
#  opt_numeric_ids           :boolean          default(FALSE), not null
#  opt_one_file_system       :boolean          default(FALSE), not null
#  opt_owner                 :boolean          default(FALSE), not null
#  opt_partial               :boolean          default(FALSE), not null
#  opt_perms                 :boolean          default(FALSE), not null
#  opt_progress              :boolean          default(TRUE), not null
#  opt_recursive             :boolean          default(TRUE), not null
#  opt_relative              :boolean          default(FALSE), not null
#  opt_rsync_path            :string
#  opt_secluded_args         :boolean          default(FALSE), not null
#  opt_size_only             :boolean          default(FALSE), not null
#  opt_specials              :boolean          default(FALSE), not null
#  opt_superuser             :boolean          default(FALSE), not null
#  opt_times                 :boolean          default(TRUE), not null
#  opt_update                :boolean          default(FALSE), not null
#  opt_verbose               :boolean          default(FALSE), not null
#  opt_xattrs                :boolean          default(FALSE), not null
#  schedule                  :string           indexed
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  destination_repository_id :uuid             not null, indexed
#  source_repository_id      :uuid             not null, indexed
#  user_id                   :uuid             not null, indexed
#
# Indexes
#
#  index_jobs_on_description_trgm           (description) USING gin
#  index_jobs_on_destination_repository_id  (destination_repository_id)
#  index_jobs_on_name                       (name)
#  index_jobs_on_name_trgm                  (name) USING gin
#  index_jobs_on_schedule                   (schedule)
#  index_jobs_on_source_repository_id       (source_repository_id)
#  index_jobs_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (destination_repository_id => repositories.id)
#  fk_rails_...  (source_repository_id => repositories.id)
#  fk_rails_...  (user_id => users.id)
#
