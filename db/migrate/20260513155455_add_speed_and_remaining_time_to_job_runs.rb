# frozen_string_literal: true

class AddSpeedAndRemainingTimeToJobRuns < ActiveRecord::Migration[8.1]
  def change
    change_table :job_runs, bulk: true do |t|
      t.integer :speed
      t.integer :remaining_time
    end
  end
end
