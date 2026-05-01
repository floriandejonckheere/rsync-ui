# frozen_string_literal: true

class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.text :description
      t.text :url, null: false
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end
  end
end
