# frozen_string_literal: true

class RestrictRepositoryDeletionForJobs < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :jobs, :repositories, column: :source_repository_id
    remove_foreign_key :jobs, :repositories, column: :destination_repository_id

    add_foreign_key :jobs, :repositories, column: :source_repository_id, on_delete: :restrict
    add_foreign_key :jobs, :repositories, column: :destination_repository_id, on_delete: :restrict
  end
end
