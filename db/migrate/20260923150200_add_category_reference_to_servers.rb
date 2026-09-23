# frozen_string_literal: true

class AddCategoryReferenceToServers < ActiveRecord::Migration[8.1]
  def up
    add_reference :servers, :category, type: :uuid, foreign_key: { on_delete: :nullify }

    # Create one category per user and (case-insensitive) name, keeping the alphabetically first spelling
    execute <<~SQL.squish
      INSERT INTO categories (user_id, categorizable_type, name, created_at, updated_at)
      SELECT DISTINCT ON (user_id, lower(btrim(category))) user_id, 'Server', btrim(category), NOW(), NOW()
      FROM servers
      WHERE btrim(category) <> ''
      ORDER BY user_id, lower(btrim(category)), btrim(category)
    SQL

    execute <<~SQL.squish
      UPDATE servers
      SET category_id = categories.id
      FROM categories
      WHERE categories.user_id = servers.user_id
        AND categories.categorizable_type = 'Server'
        AND lower(categories.name) = lower(btrim(servers.category))
    SQL

    remove_column :servers, :category
  end

  def down
    add_column :servers, :category, :string
    add_index :servers, :category

    execute <<~SQL.squish
      UPDATE servers
      SET category = categories.name
      FROM categories
      WHERE categories.id = servers.category_id
    SQL

    execute "DELETE FROM categories WHERE categorizable_type = 'Server'"

    remove_reference :servers, :category, type: :uuid, foreign_key: true
  end
end
