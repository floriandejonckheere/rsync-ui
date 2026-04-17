# frozen_string_literal: true

class CreateServers < ActiveRecord::Migration[8.1]
  def change
    create_table :servers, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.string :host, null: false
      t.integer :port, null: false, default: 22
      t.string :username, null: false
      t.text :password
      t.text :ssh_key

      t.references :user, type: :uuid, null: false, foreign_key: true

      t.timestamps
    end
  end
end
