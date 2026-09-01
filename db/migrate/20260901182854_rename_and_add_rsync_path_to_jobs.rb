# frozen_string_literal: true

class RenameAndAddRsyncPathToJobs < ActiveRecord::Migration[8.1]
  def change
    rename_column :jobs, :opt_rsync_path, :opt_local_rsync_path
    add_column :jobs, :opt_remote_rsync_path, :string
  end
end
