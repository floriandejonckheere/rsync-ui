# frozen_string_literal: true

class AddConnectivityToServers < ActiveRecord::Migration[8.0]
  def change
    change_table :servers, bulk: true do |t|
      t.datetime :probed_at
      t.datetime :last_seen_at
      t.string :error_class
      t.text :error_message
    end
  end
end
