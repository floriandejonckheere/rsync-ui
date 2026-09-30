# frozen_string_literal: true

class AddRsyncVersionToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :rsync_version, :string, null: false, default: "3.5.1"
  end
end
