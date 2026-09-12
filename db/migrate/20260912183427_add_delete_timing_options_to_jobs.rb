# frozen_string_literal: true

class AddDeleteTimingOptionsToJobs < ActiveRecord::Migration[8.1]
  def change
    change_table :jobs, bulk: true do |t|
      t.boolean :opt_delete_before, null: false, default: false
      t.boolean :opt_delete_during, null: false, default: false
      t.boolean :opt_delete_delay, null: false, default: false
      t.boolean :opt_delete_after, null: false, default: false
    end
  end
end
