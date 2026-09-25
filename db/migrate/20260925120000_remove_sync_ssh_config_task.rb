# frozen_string_literal: true

class RemoveSyncSSHConfigTask < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM tasks WHERE class_name = 'Servers::SyncSSHConfigTask'"
  end

  def down
    execute <<~SQL.squish
      INSERT INTO tasks (name, class_name, created_at, updated_at)
      VALUES ('sync_ssh_config', 'Servers::SyncSSHConfigTask', NOW(), NOW())
      ON CONFLICT (name) DO NOTHING
    SQL
  end
end
