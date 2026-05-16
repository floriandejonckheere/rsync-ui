# frozen_string_literal: true

class AddFingerprintToServers < ActiveRecord::Migration[8.1]
  def change
    add_column :servers, :fingerprint, :string
  end
end
