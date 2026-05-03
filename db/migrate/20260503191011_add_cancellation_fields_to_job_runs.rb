# frozen_string_literal: true

class AddCancellationFieldsToJobRuns < ActiveRecord::Migration[8.1]
  def change
    change_table :job_runs, bulk: true do |t|
      t.datetime :cancel_requested_at
      t.datetime :canceled_at
      t.integer :pid
    end

    add_index :job_runs, :canceled_at
  end
end
