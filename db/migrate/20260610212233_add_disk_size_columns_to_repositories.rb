# frozen_string_literal: true

class AddDiskSizeColumnsToRepositories < ActiveRecord::Migration[8.1]
  def change
    change_table :repositories, bulk: true do |t|
      t.bigint :disk_size
      t.string :disk_size_status
      t.string :disk_size_error_class
      t.text :disk_size_error_message
      t.datetime :disk_size_measured_at

      t.index :disk_size_measured_at
    end
  end
end
