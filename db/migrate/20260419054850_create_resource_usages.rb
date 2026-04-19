# frozen_string_literal: true

class CreateResourceUsages < ActiveRecord::Migration[8.1]
  def change
    add_column :servers, :path, :string, default: "/", null: false

    create_table :resource_usages, id: :uuid do |t|
      t.references :server, type: :uuid, null: false, foreign_key: { dependent: :destroy }, index: { unique: true }

      t.datetime :probed_at

      t.string :status

      t.string :probe_error_class
      t.text :probe_error_message

      t.integer :cpu_count
      t.float :cpu_usage

      t.bigint :memory_total
      t.bigint :memory_used

      t.bigint :disk_total
      t.bigint :disk_used

      t.bigint :uptime_seconds

      t.float :load_avg_1
      t.float :load_avg_5
      t.float :load_avg_15
      # rubocop:enable Naming/VariableNumber

      t.timestamps
    end
  end
end
