# frozen_string_literal: true

class AddFilesTransferredAndFilesTotalToJobRuns < ActiveRecord::Migration[8.1]
  def change
    change_table :job_runs, bulk: true do |t|
      t.integer :files_transferred
      t.integer :files_total
    end
  end
end
