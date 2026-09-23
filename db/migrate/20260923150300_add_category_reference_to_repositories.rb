# frozen_string_literal: true

class AddCategoryReferenceToRepositories < ActiveRecord::Migration[8.1]
  def up
    add_reference :repositories, :category, type: :uuid, foreign_key: { on_delete: :nullify }

    # Create one category per user and (case-insensitive) name, keeping the alphabetically first spelling
    execute <<~SQL.squish
      INSERT INTO categories (user_id, categorizable_type, name, created_at, updated_at)
      SELECT DISTINCT ON (user_id, lower(btrim(category))) user_id, 'Repository', btrim(category), NOW(), NOW()
      FROM repositories
      WHERE btrim(category) <> ''
      ORDER BY user_id, lower(btrim(category)), btrim(category)
    SQL

    execute <<~SQL.squish
      UPDATE repositories
      SET category_id = categories.id
      FROM categories
      WHERE categories.user_id = repositories.user_id
        AND categories.categorizable_type = 'Repository'
        AND lower(categories.name) = lower(btrim(repositories.category))
    SQL

    remove_column :repositories, :category
  end

  def down
    add_column :repositories, :category, :string
    add_index :repositories, :category

    execute <<~SQL.squish
      UPDATE repositories
      SET category = categories.name
      FROM categories
      WHERE categories.id = repositories.category_id
    SQL

    execute "DELETE FROM categories WHERE categorizable_type = 'Repository'"

    remove_reference :repositories, :category, type: :uuid, foreign_key: true
  end
end
