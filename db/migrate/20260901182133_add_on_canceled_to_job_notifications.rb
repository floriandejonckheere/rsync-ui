# frozen_string_literal: true

class AddOnCanceledToJobNotifications < ActiveRecord::Migration[8.0]
  def change
    add_column :job_notifications, :on_canceled, :boolean, null: false, default: false
  end
end
