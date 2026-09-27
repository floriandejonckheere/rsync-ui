# frozen_string_literal: true

class AddPingToJobs < ActiveRecord::Migration[8.1]
  def change
    change_table :jobs, bulk: true do |t|
      t.boolean :ping, null: false, default: false
      t.string :ping_action, null: false, default: "abort"
    end
  end
end
