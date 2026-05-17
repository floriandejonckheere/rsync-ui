# frozen_string_literal: true

class AddSSHArgumentsToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :opt_ssh_arguments, :text
  end
end
