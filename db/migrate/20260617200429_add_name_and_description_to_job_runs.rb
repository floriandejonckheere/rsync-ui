# frozen_string_literal: true

class AddNameAndDescriptionToJobRuns < ActiveRecord::Migration[8.1]
  def change
    change_table :job_runs, bulk: true do |t|
      t.string :name, null: false, default: ""
      t.text :description
    end
  end
end
