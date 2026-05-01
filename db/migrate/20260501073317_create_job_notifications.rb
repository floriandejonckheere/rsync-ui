# frozen_string_literal: true

class CreateJobNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :job_notifications, id: :uuid do |t|
      t.references :job, type: :uuid, null: false, foreign_key: true, index: true
      t.references :notification, type: :uuid, null: false, foreign_key: true, index: true

      t.boolean :enabled, null: false, default: true
      t.boolean :on_start, null: false, default: false
      t.boolean :on_success, null: false, default: true
      t.boolean :on_failure, null: false, default: true

      t.timestamps

      t.index [:job_id, :notification_id], unique: true
    end
  end
end
