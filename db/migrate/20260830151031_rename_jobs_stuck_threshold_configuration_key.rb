# frozen_string_literal: true

class RenameJobsStuckThresholdConfigurationKey < ActiveRecord::Migration[8.1]
  def up
    Configuration
      .where(key: "terminate_stuck_jobs.interval")
      .destroy_all

    Configuration
      .where(key: "jobs.stuck_threshold")
      .find_each { |configuration| configuration.update!(key: "terminate_stuck_jobs.interval") }
  end

  def down
    Configuration
      .where(key: "terminate_stuck_jobs.interval")
      .find_each { |configuration| configuration.update!(key: "jobs.stuck_threshold") }
  end
end
