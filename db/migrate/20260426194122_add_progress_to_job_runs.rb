# frozen_string_literal: true

class AddProgressToJobRuns < ActiveRecord::Migration[8.1]
  def change
    change_table :job_runs, bulk: true do |t|
      t.bigint :bytes_copied, null: false, default: 0
      t.integer :progress, null: false, default: 0
    end
  end
end
