# frozen_string_literal: true

class AddSortAndSearchIndexes < ActiveRecord::Migration[8.1]
  def change
    # B-tree indexes for ORDER BY on sort columns
    add_index :servers, :name
    add_index :servers, :host
    add_index :repositories, :name
    add_index :repositories, :repository_type
    add_index :repositories, :path
    add_index :jobs, :name
    add_index :jobs, :schedule
    add_index :job_runs, :sequence
    add_index :job_runs, :status
    add_index :job_runs, :started_at
    add_index :job_runs, :completed_at

    # GIN trigram indexes for ILIKE %value% search queries
    enable_extension "pg_trgm"
    add_index :servers, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_servers_on_name_trgm"
    add_index :servers, :host, using: :gin, opclass: :gin_trgm_ops, name: "index_servers_on_host_trgm"
    add_index :servers, :description, using: :gin, opclass: :gin_trgm_ops, name: "index_servers_on_description_trgm"
    add_index :repositories, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_repositories_on_name_trgm"
    add_index :repositories, :description, using: :gin, opclass: :gin_trgm_ops, name: "index_repositories_on_description_trgm"
    add_index :jobs, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_jobs_on_name_trgm"
    add_index :jobs, :description, using: :gin, opclass: :gin_trgm_ops, name: "index_jobs_on_description_trgm"
  end
end
