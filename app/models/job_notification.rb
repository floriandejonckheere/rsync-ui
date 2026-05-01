# frozen_string_literal: true

class JobNotification < ApplicationRecord
  belongs_to :job
  belongs_to :notification

  validates :notification_id,
            uniqueness: { scope: :job_id }
end

# == Schema Information
#
# Table name: job_notifications
#
#  id              :uuid             not null, primary key
#  enabled         :boolean          default(TRUE), not null
#  on_failure      :boolean          default(TRUE), not null
#  on_start        :boolean          default(FALSE), not null
#  on_success      :boolean          default(TRUE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  job_id          :uuid             not null, indexed, uniquely indexed => [notification_id]
#  notification_id :uuid             not null, uniquely indexed => [job_id], indexed
#
# Indexes
#
#  index_job_notifications_on_job_id                      (job_id)
#  index_job_notifications_on_job_id_and_notification_id  (job_id,notification_id) UNIQUE
#  index_job_notifications_on_notification_id             (notification_id)
#
# Foreign Keys
#
#  fk_rails_...  (job_id => jobs.id)
#  fk_rails_...  (notification_id => notifications.id)
#
