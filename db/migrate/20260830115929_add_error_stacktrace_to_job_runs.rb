# frozen_string_literal: true

class AddErrorStacktraceToJobRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :job_runs, :error_stacktrace, :text
  end
end
