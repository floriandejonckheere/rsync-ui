# frozen_string_literal: true

class CreateJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :jobs, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.string :schedule
      t.boolean :enabled, null: false, default: true

      t.references :source_repository, type: :uuid, null: false, foreign_key: { to_table: :repositories }
      t.references :destination_repository, type: :uuid, null: false, foreign_key: { to_table: :repositories }
      t.references :user, type: :uuid, null: false, foreign_key: true

      t.timestamps
    end
  end
end
