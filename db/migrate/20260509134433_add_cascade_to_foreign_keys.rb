# frozen_string_literal: true

class AddCascadeToForeignKeys < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :repositories, :servers
    add_foreign_key :repositories, :servers, on_delete: :cascade

    remove_foreign_key :jobs, :repositories, column: :source_repository_id
    add_foreign_key :jobs, :repositories, column: :source_repository_id, on_delete: :cascade

    remove_foreign_key :jobs, :repositories, column: :destination_repository_id
    add_foreign_key :jobs, :repositories, column: :destination_repository_id, on_delete: :cascade
  end
end
