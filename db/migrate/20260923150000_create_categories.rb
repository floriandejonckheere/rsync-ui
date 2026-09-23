# frozen_string_literal: true

class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :categorizable_type, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :categories,
              "user_id, categorizable_type, lower(name)",
              unique: true,
              name: "index_categories_on_user_id_and_categorizable_type_and_name"
  end
end
