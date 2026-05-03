# frozen_string_literal: true

class RenameProbeErrorColumnsInResourceUsages < ActiveRecord::Migration[8.1]
  def change
    rename_column :resource_usages, :probe_error_class, :error_class
    rename_column :resource_usages, :probe_error_message, :error_message
  end
end
