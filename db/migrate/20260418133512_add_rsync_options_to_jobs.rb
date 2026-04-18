# frozen_string_literal: true

class AddRsyncOptionsToJobs < ActiveRecord::Migration[8.1]
  def change
    change_table :jobs, bulk: true do |t|
      # Basic options
      t.boolean :opt_archive, null: false, default: false
      t.boolean :opt_recursive, null: false, default: true
      t.boolean :opt_relative, null: false, default: false
      t.boolean :opt_links, null: false, default: true
      t.boolean :opt_times, null: false, default: true
      t.boolean :opt_perms, null: false, default: false
      t.boolean :opt_owner, null: false, default: false
      t.boolean :opt_group, null: false, default: false
      t.boolean :opt_one_file_system, null: false, default: false
      t.boolean :opt_delete, null: false, default: false
      t.boolean :opt_delete_excluded, null: false, default: false
      t.boolean :opt_existing, null: false, default: false
      t.boolean :opt_ignore_existing, null: false, default: false
      t.boolean :opt_update, null: false, default: false
      t.boolean :opt_dry_run, null: false, default: false
      t.boolean :opt_inplace, null: false, default: false
      t.boolean :opt_size_only, null: false, default: false
      t.boolean :opt_progress, null: false, default: true

      # Advanced options
      t.boolean :opt_acls, null: false, default: false
      t.boolean :opt_xattrs, null: false, default: false
      t.boolean :opt_hard_links, null: false, default: false
      t.boolean :opt_devices, null: false, default: false
      t.boolean :opt_specials, null: false, default: false
      t.boolean :opt_checksum, null: false, default: false
      t.boolean :opt_compress, null: false, default: false
      t.boolean :opt_partial, null: false, default: false
      t.boolean :opt_backup, null: false, default: false
      t.boolean :opt_append, null: false, default: false
      t.boolean :opt_numeric_ids, null: false, default: false
      t.boolean :opt_itemize_changes, null: false, default: false
      t.boolean :opt_secluded_args, null: false, default: false
      t.boolean :opt_verbose, null: false, default: false

      # Custom options
      t.boolean :opt_superuser, null: false, default: false
      t.text :opt_arguments
      t.string :opt_rsync_path
    end
  end
end
