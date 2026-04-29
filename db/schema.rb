# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_29_000003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "configurations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "type", default: "Configuration::String", null: false
    t.datetime "updated_at", null: false
    t.jsonb "value", null: false
    t.index ["key"], name: "index_configurations_on_key", unique: true
  end

  create_table "job_runs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "bytes_copied", default: 0, null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "error_class"
    t.text "error_messages"
    t.uuid "job_id", null: false
    t.integer "progress", default: 0, null: false
    t.serial "sequence", null: false
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.string "trigger", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["completed_at"], name: "index_job_runs_on_completed_at"
    t.index ["job_id"], name: "index_job_runs_on_job_id"
    t.index ["sequence"], name: "index_job_runs_on_sequence"
    t.index ["started_at"], name: "index_job_runs_on_started_at"
    t.index ["status"], name: "index_job_runs_on_status"
    t.index ["user_id"], name: "index_job_runs_on_user_id"
  end

  create_table "jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.uuid "destination_repository_id", null: false
    t.boolean "enabled", default: true, null: false
    t.string "name", null: false
    t.boolean "opt_acls", default: false, null: false
    t.boolean "opt_append", default: false, null: false
    t.boolean "opt_archive", default: false, null: false
    t.text "opt_arguments"
    t.boolean "opt_backup", default: false, null: false
    t.boolean "opt_checksum", default: false, null: false
    t.boolean "opt_compress", default: false, null: false
    t.boolean "opt_delete", default: false, null: false
    t.boolean "opt_delete_excluded", default: false, null: false
    t.boolean "opt_devices", default: false, null: false
    t.boolean "opt_dry_run", default: false, null: false
    t.text "opt_exclude", default: [], null: false, array: true
    t.boolean "opt_existing", default: false, null: false
    t.boolean "opt_group", default: false, null: false
    t.boolean "opt_hard_links", default: false, null: false
    t.boolean "opt_ignore_existing", default: false, null: false
    t.text "opt_include", default: [], null: false, array: true
    t.boolean "opt_inplace", default: false, null: false
    t.boolean "opt_itemize_changes", default: false, null: false
    t.boolean "opt_links", default: true, null: false
    t.boolean "opt_numeric_ids", default: false, null: false
    t.boolean "opt_one_file_system", default: false, null: false
    t.boolean "opt_owner", default: false, null: false
    t.boolean "opt_partial", default: false, null: false
    t.boolean "opt_perms", default: false, null: false
    t.boolean "opt_progress", default: true, null: false
    t.boolean "opt_recursive", default: true, null: false
    t.boolean "opt_relative", default: false, null: false
    t.string "opt_rsync_path"
    t.boolean "opt_secluded_args", default: false, null: false
    t.boolean "opt_size_only", default: false, null: false
    t.boolean "opt_specials", default: false, null: false
    t.boolean "opt_superuser", default: false, null: false
    t.boolean "opt_times", default: true, null: false
    t.boolean "opt_update", default: false, null: false
    t.boolean "opt_verbose", default: false, null: false
    t.boolean "opt_xattrs", default: false, null: false
    t.string "schedule"
    t.uuid "source_repository_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["description"], name: "index_jobs_on_description_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["destination_repository_id"], name: "index_jobs_on_destination_repository_id"
    t.index ["name"], name: "index_jobs_on_name"
    t.index ["name"], name: "index_jobs_on_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["schedule"], name: "index_jobs_on_schedule"
    t.index ["source_repository_id"], name: "index_jobs_on_source_repository_id"
    t.index ["user_id"], name: "index_jobs_on_user_id"
  end

  create_table "repositories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "path", null: false
    t.boolean "read_only", default: false, null: false
    t.string "repository_type", null: false
    t.uuid "server_id"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["description"], name: "index_repositories_on_description_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["name"], name: "index_repositories_on_name"
    t.index ["name"], name: "index_repositories_on_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["path"], name: "index_repositories_on_path"
    t.index ["repository_type"], name: "index_repositories_on_repository_type"
    t.index ["server_id"], name: "index_repositories_on_server_id"
    t.index ["user_id"], name: "index_repositories_on_user_id"
  end

  create_table "resource_usages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "cpu_count"
    t.float "cpu_usage"
    t.datetime "created_at", null: false
    t.bigint "disk_total"
    t.bigint "disk_used"
    t.float "load_avg_1"
    t.float "load_avg_15"
    t.float "load_avg_5"
    t.bigint "memory_total"
    t.bigint "memory_used"
    t.string "probe_error_class"
    t.text "probe_error_message"
    t.datetime "probed_at"
    t.uuid "server_id", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.bigint "uptime_seconds"
    t.index ["server_id"], name: "index_resource_usages_on_server_id", unique: true
  end

  create_table "servers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "host", null: false
    t.string "name", null: false
    t.text "password"
    t.string "path", default: "/", null: false
    t.integer "port", default: 22, null: false
    t.text "ssh_key"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.string "username", null: false
    t.index ["description"], name: "index_servers_on_description_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["host"], name: "index_servers_on_host"
    t.index ["host"], name: "index_servers_on_host_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["name"], name: "index_servers_on_name"
    t.index ["name"], name: "index_servers_on_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["user_id"], name: "index_servers_on_user_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name", default: "", null: false
    t.string "last_name", default: "", null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "user", null: false
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "job_runs", "jobs"
  add_foreign_key "job_runs", "users"
  add_foreign_key "jobs", "repositories", column: "destination_repository_id"
  add_foreign_key "jobs", "repositories", column: "source_repository_id"
  add_foreign_key "jobs", "users"
  add_foreign_key "repositories", "servers"
  add_foreign_key "repositories", "users"
  add_foreign_key "resource_usages", "servers"
  add_foreign_key "servers", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
