# frozen_string_literal: true

class ChangeSpeedToBigintInJobRuns < ActiveRecord::Migration[8.1]
  def change
    change_column :job_runs, :speed, :bigint # rubocop:disable Rails/ReversibleMigration
  end
end
