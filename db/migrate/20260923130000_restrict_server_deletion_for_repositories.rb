# frozen_string_literal: true

class RestrictServerDeletionForRepositories < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :repositories, :servers

    add_foreign_key :repositories, :servers, on_delete: :restrict
  end
end
