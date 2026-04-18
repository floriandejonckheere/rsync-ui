# frozen_string_literal: true

class AddErrorColumnsToJobRuns < ActiveRecord::Migration[8.1]
  def change
    change_table :job_runs, bulk: true do |t|
      t.string :error_class
      t.text :error_messages
    end
  end
end
