# frozen_string_literal: true

class RenameJobRunErrorMessagesToErrorMessage < ActiveRecord::Migration[8.1]
  def change
    rename_column :job_runs, :error_messages, :error_message
  end
end
