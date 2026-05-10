# frozen_string_literal: true

class AddLastHeartbeatAtToJobRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :job_runs, :last_heartbeat_at, :datetime
    add_index :job_runs, :last_heartbeat_at
  end
end
