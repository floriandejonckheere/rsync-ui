# frozen_string_literal: true

class AddCategoryReferenceToJobs < ActiveRecord::Migration[8.1]
  def up
    add_reference :jobs, :category, type: :uuid, foreign_key: { on_delete: :nullify }

    # Create one category per user and (case-insensitive) name, keeping the alphabetically first spelling
    execute <<~SQL.squish
      INSERT INTO categories (user_id, categorizable_type, name, created_at, updated_at)
      SELECT DISTINCT ON (user_id, lower(btrim(category))) user_id, 'Job', btrim(category), NOW(), NOW()
      FROM jobs
      WHERE btrim(category) <> ''
      ORDER BY user_id, lower(btrim(category)), btrim(category)
    SQL

    execute <<~SQL.squish
      UPDATE jobs
      SET category_id = categories.id
      FROM categories
      WHERE categories.user_id = jobs.user_id
        AND categories.categorizable_type = 'Job'
        AND lower(categories.name) = lower(btrim(jobs.category))
    SQL

    remove_column :jobs, :category
  end

  def down
    add_column :jobs, :category, :string
    add_index :jobs, :category

    execute <<~SQL.squish
      UPDATE jobs
      SET category = categories.name
      FROM categories
      WHERE categories.id = jobs.category_id
    SQL

    execute "DELETE FROM categories WHERE categorizable_type = 'Job'"

    remove_reference :jobs, :category, type: :uuid, foreign_key: true
  end
end
