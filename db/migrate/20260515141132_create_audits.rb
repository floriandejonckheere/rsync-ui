# frozen_string_literal: true

class CreateAudits < ActiveRecord::Migration[8.1]
  def change
    create_table :audits, id: :uuid do |t|
      t.references :server, null: false, foreign_key: { on_delete: :cascade }, type: :uuid

      t.text :command, null: false
      t.text :output, null: false, default: ""
      t.integer :exit_status
      t.datetime :started_at, null: false
      t.datetime :completed_at

      t.timestamps
    end

    add_index :audits, :started_at
    add_index :audits, :exit_status
  end
end
