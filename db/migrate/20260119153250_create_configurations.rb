# frozen_string_literal: true

class CreateConfigurations < ActiveRecord::Migration[8.1]
  def change
    create_table :configurations, id: :uuid do |t|
      t.string :key, null: false, index: { unique: true }
      t.jsonb :value, null: false
      t.string :type, null: false, default: "Configuration::String"

      t.timestamps
    end
  end
end
