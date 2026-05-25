# frozen_string_literal: true

class AddHookStatusColumnsToJobRuns < ActiveRecord::Migration[8.1]
  def change
    change_table :job_runs, bulk: true do |t|
      t.string :pre_hook_status
      t.integer :pre_hook_exit_status
      t.string :pre_hook_error_class
      t.text :pre_hook_error_message

      t.string :post_hook_status
      t.integer :post_hook_exit_status
      t.string :post_hook_error_class
      t.text :post_hook_error_message

      t.string :success_hook_status
      t.integer :success_hook_exit_status
      t.string :success_hook_error_class
      t.text :success_hook_error_message

      t.string :failure_hook_status
      t.integer :failure_hook_exit_status
      t.string :failure_hook_error_class
      t.text :failure_hook_error_message
    end
  end
end
