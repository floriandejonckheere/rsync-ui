# frozen_string_literal: true

class ChangeOptProgressDefaultInJobs < ActiveRecord::Migration[8.1]
  def change
    change_column_default :jobs, :opt_progress, from: true, to: false
  end
end
