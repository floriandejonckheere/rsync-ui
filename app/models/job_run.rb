# frozen_string_literal: true

class JobRun < ApplicationRecord
  belongs_to :job
  belongs_to :user

  has_one_attached :output

  enum :trigger, {
    manual: "manual",
    scheduled: "scheduled",
  }, validate: true

  enum :status, {
    pending: "pending",
    running: "running",
    completed: "completed",
    failed: "failed",
    canceled: "canceled",
    errored: "errored",
  }, validate: true

  validates :trigger,
            presence: true

  validates :status,
            presence: true

  scope :by_job, ->(job_id) { where(job_id:) if job_id.present? }
  scope :by_trigger, ->(trigger) { where(trigger:) if trigger.present? }
  scope :by_status, ->(status) { where(status:) if status.present? }

  scope :started_from, ->(from) { where(started_at: from..) if from.present? }
  scope :started_to, ->(to) { where(started_at: ..to) if to.present? }

  def duration
    return unless started_at

    (completed_at || Time.current) - started_at
  end

  def deletable?
    completed? || failed? || canceled? || errored?
  end
end

# == Schema Information
#
# Table name: job_runs
#
#  id             :uuid             not null, primary key
#  bytes_copied   :bigint           default(0), not null
#  completed_at   :datetime         indexed
#  error_class    :string
#  error_messages :text
#  progress       :integer          default(0), not null
#  sequence       :integer          not null, indexed
#  started_at     :datetime         indexed
#  status         :string           default("pending"), not null, indexed
#  trigger        :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  job_id         :uuid             not null, indexed
#  user_id        :uuid             not null, indexed
#
# Indexes
#
#  index_job_runs_on_completed_at  (completed_at)
#  index_job_runs_on_job_id        (job_id)
#  index_job_runs_on_sequence      (sequence)
#  index_job_runs_on_started_at    (started_at)
#  index_job_runs_on_status        (status)
#  index_job_runs_on_user_id       (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (job_id => jobs.id)
#  fk_rails_...  (user_id => users.id)
#
