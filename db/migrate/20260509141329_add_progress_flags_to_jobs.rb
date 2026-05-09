# frozen_string_literal: true

class AddProgressFlagsToJobs < ActiveRecord::Migration[8.0]
  def change
    change_table :jobs, bulk: true do |t|
      t.boolean :opt_progress2, default: true, null: false
      t.boolean :opt_no_inc_recursive, default: true, null: false
    end
  end
end
