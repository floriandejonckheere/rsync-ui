# frozen_string_literal: true

class MakeJobRunProgressOptional < ActiveRecord::Migration[8.0]
  def change
    change_table :job_runs, bulk: true do |_t|
      change_column_null :job_runs, :bytes_copied, true
      change_column_default :job_runs, :bytes_copied, from: 0, to: nil
    end
  end
end
