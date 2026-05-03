# frozen_string_literal: true

class CreateHooks < ActiveRecord::Migration[8.0]
  def change
    create_table :hooks, id: :uuid do |t|
      t.references :job, type: :uuid, null: false, foreign_key: true, index: true
      t.string :hook_type, null: false
      t.string :command, null: false
      t.string :arguments
      t.boolean :enabled, null: false, default: false

      t.timestamps
    end
  end
end
