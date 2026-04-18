# frozen_string_literal: true

class CreateJobRuns < ActiveRecord::Migration[8.1]
  def up
    execute "CREATE SEQUENCE job_runs_sequence_seq"

    create_table :job_runs, id: :uuid do |t|
      t.references :job, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.integer :sequence, null: false, default: -> { "nextval('job_runs_sequence_seq')" }
      t.string :trigger, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    execute "ALTER SEQUENCE job_runs_sequence_seq OWNED BY job_runs.sequence"
  end

  def down
    drop_table :job_runs

    execute "DROP SEQUENCE job_runs_sequence_seq"
  end
end
