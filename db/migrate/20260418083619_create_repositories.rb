# frozen_string_literal: true

class CreateRepositories < ActiveRecord::Migration[8.1]
  def change
    create_table :repositories, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.string :repository_type, null: false
      t.string :path, null: false
      t.boolean :read_only, null: false, default: false

      t.references :server, type: :uuid, null: true, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true

      t.timestamps
    end
  end
end
