# frozen_string_literal: true

class AddHostKeyToServers < ActiveRecord::Migration[8.1]
  def change
    add_column :servers, :host_key, :text
  end
end
