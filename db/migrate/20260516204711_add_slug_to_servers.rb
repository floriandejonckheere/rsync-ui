# frozen_string_literal: true

class AddSlugToServers < ActiveRecord::Migration[8.1]
  def change
    add_column :servers, :slug, :string, null: false, default: ""
    add_index :servers, :slug, unique: true
  end
end
