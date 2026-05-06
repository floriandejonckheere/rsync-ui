# frozen_string_literal: true

class AddOperatingSystemToServers < ActiveRecord::Migration[8.0]
  def change
    add_column :servers, :operating_system, :string, default: "linux"
  end
end
