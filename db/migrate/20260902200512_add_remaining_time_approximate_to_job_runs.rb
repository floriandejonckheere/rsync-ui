# frozen_string_literal: true

class AddRemainingTimeApproximateToJobRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :job_runs, :remaining_time_approximate, :boolean, default: false, null: false
  end
end
