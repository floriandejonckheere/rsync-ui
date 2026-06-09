# frozen_string_literal: true

class JobRun < ApplicationRecord
  include JobRuns::StateMachine

  NOTIFICATION_EVENTS = {
    "running" => "start",
    "completed" => "success",
    "failed" => "failure",
    "errored" => "failure",
  }.freeze

  belongs_to :job
  belongs_to :user

  has_one_attached :output
  has_one_attached :pre_hook_output
  has_one_attached :post_hook_output
  has_one_attached :success_hook_output
  has_one_attached :failure_hook_output

  enum :trigger, {
    manual: "manual",
    scheduled: "scheduled",
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

  after_commit :enqueue_status_notifications, on: [:create, :update]

  def duration
    return unless started_at

    (completed_at || Time.current) - started_at
  end

  private

  def enqueue_status_notifications
    return unless Configuration.get("notifications")
    return unless saved_change_to_status?

    event = NOTIFICATION_EVENTS[status]
    return unless event

    job.job_notifications.find_each do |job_notification|
      Notifications::SendJob.perform_later(job_notification.id, id, event)
    end
  end
end

# == Schema Information
#
# Table name: job_runs
#
#  id                         :uuid             not null, primary key
#  bytes_copied               :bigint
#  cancel_requested_at        :datetime
#  canceled_at                :datetime         indexed
#  command                    :text
#  completed_at               :datetime         indexed
#  error_class                :string
#  error_message              :text
#  failure_hook_error_class   :string
#  failure_hook_error_message :text
#  failure_hook_exit_status   :integer
#  failure_hook_status        :string
#  pid                        :integer
#  post_hook_error_class      :string
#  post_hook_error_message    :text
#  post_hook_exit_status      :integer
#  post_hook_status           :string
#  pre_hook_error_class       :string
#  pre_hook_error_message     :text
#  pre_hook_exit_status       :integer
#  pre_hook_status            :string
#  progress                   :integer
#  remaining_time             :integer
#  sequence                   :integer          not null, indexed
#  speed                      :integer
#  started_at                 :datetime         indexed
#  status                     :string           default("pending"), not null, indexed
#  success_hook_error_class   :string
#  success_hook_error_message :text
#  success_hook_exit_status   :integer
#  success_hook_status        :string
#  trigger                    :string           not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  job_id                     :uuid             not null, indexed
#  user_id                    :uuid             not null, indexed
#
# Indexes
#
#  index_job_runs_on_canceled_at   (canceled_at)
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
