# frozen_string_literal: true

class JobRun < ApplicationRecord
  belongs_to :job
  belongs_to :user

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
  }, validate: true

  validates :trigger,
            presence: true

  validates :status,
            presence: true

  def duration
    return unless started_at

    (completed_at || Time.current) - started_at
  end

  def deletable?
    completed? || failed? || canceled?
  end
end

# == Schema Information
#
# Table name: job_runs
#
#  id           :uuid             not null, primary key
#  completed_at :datetime
#  sequence     :integer          not null
#  started_at   :datetime
#  status       :string           default("pending"), not null
#  trigger      :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  job_id       :uuid             not null, indexed
#  user_id      :uuid             not null, indexed
#
# Indexes
#
#  index_job_runs_on_job_id   (job_id)
#  index_job_runs_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (job_id => jobs.id)
#  fk_rails_...  (user_id => users.id)
#
