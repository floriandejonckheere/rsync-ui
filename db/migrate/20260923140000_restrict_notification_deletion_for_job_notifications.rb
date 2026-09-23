# frozen_string_literal: true

class RestrictNotificationDeletionForJobNotifications < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :job_notifications, :notifications

    add_foreign_key :job_notifications, :notifications, on_delete: :restrict
  end
end
