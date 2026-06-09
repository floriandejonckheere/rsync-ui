# frozen_string_literal: true

class AddExitStatusToJobRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :job_runs, :exit_status, :integer
  end
end
