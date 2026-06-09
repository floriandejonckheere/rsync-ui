# frozen_string_literal: true

class AddCommandToJobRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :job_runs, :command, :text
  end
end
