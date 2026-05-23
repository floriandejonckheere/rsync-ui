# frozen_string_literal: true

class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks, id: :uuid do |t|
      t.string :name, null: false
      t.string :class_name, null: false
      t.datetime :last_run_at
      t.references :last_run_by, type: :uuid, foreign_key: { to_table: :users, on_delete: :nullify }, null: true
      t.string :status
      t.string :configuration
      t.string :error_class
      t.text :error_message

      t.timestamps
    end

    add_index :tasks, :name, unique: true
  end
end
