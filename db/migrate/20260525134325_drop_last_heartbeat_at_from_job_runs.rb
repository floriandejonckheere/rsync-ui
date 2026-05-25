# frozen_string_literal: true

class DropLastHeartbeatAtFromJobRuns < ActiveRecord::Migration[8.1]
  def change
    remove_index :job_runs, :last_heartbeat_at
    remove_column :job_runs, :last_heartbeat_at, :datetime
  end
end
