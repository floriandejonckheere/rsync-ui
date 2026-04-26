# frozen_string_literal: true

class AddIncludeExcludeToJobs < ActiveRecord::Migration[8.1]
  def change
    change_table :jobs, bulk: true do |t|
      t.text :opt_include, array: true, null: false, default: []
      t.text :opt_exclude, array: true, null: false, default: []
    end
  end
end
