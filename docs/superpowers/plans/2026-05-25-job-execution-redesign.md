# Job Execution Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the in-process cancellation monitor and heartbeat polling with a linear executor (pre-hook → rsync → post-hook → success/failure hook) that uses explicit checkpoints, a synchronous + async cancel pathway, and a PID-liveness reaper.

**Architecture:**
- `JobRuns::ExecuteService` becomes linear: each phase spawns a process via `Processes::ExecuteService`, records its pid on the JobRun, captures its output, then re-reads the JobRun and aborts if cancellation was requested. `Processes::ExecuteService` is simplified to a dumb process runner (no monitor thread, no heartbeat, no DB polling).
- `JobRuns::CancelService` synchronously transitions `pending → canceled` or `running → canceling`, then enqueues `JobRuns::CancelJob` to send `SIGTERM` to the recorded pid. The executor observes the `canceling` state at its next checkpoint and finalizes the transition to `canceled`.
- The state machine grows a transient `canceling` state. Notifications move into `after_commit` callbacks on `JobRun` so they fire after the transaction commits (eliminating the `wait: 5.seconds` workaround).
- `Jobs::TerminateStuckJobsService` is rewritten to detect stuck runs by checking whether the recorded pid is still alive on the worker host — no more heartbeats.

**Tech Stack:** Ruby 3.4, Rails 8.0, PostgreSQL, RSpec, FactoryBot, `state_machines-activerecord`, Solid Queue.

**Spelling note:** The existing schema uses American spelling (`canceled`, `canceled_at`). This plan stays consistent — the new transient state is `canceling` (one `l`), and the final state remains `canceled`. The user's message used `cancelling`/`cancelled`; the plan deliberately uses the existing codebase's spelling.

**Operational constraint:** Only ever one worker container, fully controlled image. The reaper job must execute on the worker container so its `Process.kill(0, pid)` checks resolve against the same kernel.

---

## File Structure

**Created:**
- `app/jobs/job_runs/cancel_job.rb` — async SIGTERM sender, queued to the `workers` queue
- `db/migrate/<ts>_drop_last_heartbeat_at_from_job_runs.rb`
- `spec/jobs/job_runs/cancel_job_spec.rb`

**Modified:**
- `app/models/concerns/job_runs/state_machine.rb` — add `canceling` state, refactor transitions, move notifications to `after_commit`
- `app/services/processes/execute_service.rb` — strip monitor thread, heartbeat, cancel polling
- `app/services/hooks/execute_service.rb` — adapt to new `Processes::ExecuteService` signature, return per-hook result; persist per-hook columns
- `app/services/rsync/execute_service.rb` — drop `heartbeat_interval`
- `app/services/job_runs/execute_service.rb` — full rewrite as linear phases with checkpoints
- `app/services/job_runs/cancel_service.rb` — synchronous transition + enqueue `CancelJob`
- `app/services/jobs/terminate_stuck_jobs_service.rb` — PID-liveness reaper
- `app/jobs/jobs/execute_job.rb` — route to `workers` queue (so executor and reaper are co-located)
- `config/configurations.yml` — remove `jobs.heartbeat_interval`; rename/repurpose `jobs.stuck_threshold` as grace period for nil-pid rows
- `config/locales/configurations/en.yml` — update strings
- `spec/services/**/*_spec.rb` — update to match new architecture
- `app/services/job_runs/broadcast_service.rb` — handle `canceling` LIVE_STATES if needed (read-only review)

**Deleted:**
- `last_heartbeat_at` column on `job_runs` (via migration in Task 1)

---

## Task 1: Migration — drop `last_heartbeat_at`

**Why first:** every subsequent service edit references this column being gone, and rolling the schema change in early avoids merge conflicts in annotated model files.

**Files:**
- Create: `db/migrate/<ts>_drop_last_heartbeat_at_from_job_runs.rb`
- Modify: `app/models/job_run.rb` (annotation will auto-update via `annotaterb`)

- [ ] **Step 1: Generate the migration**

Run: `docker compose exec app bin/rails generate migration DropLastHeartbeatAtFromJobRuns`

- [ ] **Step 2: Fill in the migration**

```ruby
# frozen_string_literal: true

class DropLastHeartbeatAtFromJobRuns < ActiveRecord::Migration[8.1]
  def change
    remove_index :job_runs, :last_heartbeat_at
    remove_column :job_runs, :last_heartbeat_at, :datetime
  end
end
```

- [ ] **Step 3: Prompt user, then run migration**

Ask the user to confirm before migrating (per CLAUDE.md). On confirmation:

Run: `docker compose exec app bundle exec rails db:migrate`

Expected: migration applied, `job_runs.last_heartbeat_at` removed.

- [ ] **Step 4: Re-annotate the model**

Run: `docker compose exec app bundle exec annotaterb models`

Expected: `app/models/job_run.rb` schema comment no longer mentions `last_heartbeat_at`.

- [ ] **Step 5: Commit**

```bash
git add db/migrate/*drop_last_heartbeat_at_from_job_runs.rb db/schema.rb app/models/job_run.rb
git commit -m "Drop last_heartbeat_at column from job_runs"
```

---

## Task 2: State machine — add `canceling` state and refactor transitions

**Files:**
- Modify: `app/models/concerns/job_runs/state_machine.rb`
- Test: `spec/models/job_run_spec.rb` (or add a new spec file dedicated to state machine if missing)

**Design summary:**
- States: `pending`, `running`, `canceling` (new, transient), `completed`, `failed`, `canceled`, `errored`.
- Events:
  - `start`: `pending → running`
  - `tick`: `running → running` (unchanged, only for progress updates)
  - `complete`: `running → completed`
  - `mark_failed`: `running → failed`
  - `cancel`: `pending → canceled` (no process to kill) OR `running → canceling` (process running — needs SIGTERM via async job)
  - `finish_cancel`: `canceling → canceled` (only the executor calls this, after the process has actually exited)
  - `error`: `[pending, running, canceling] → errored` (deliberately excludes terminal states so a hook misfire after `complete!` cannot downgrade the result)

**Cancelable scope:**
- `cancelable?` becomes `pending? || running?` (canceling is already in-flight — second cancel click is a no-op).

- [ ] **Step 1: Write failing state-machine tests**

Add to `spec/models/job_run_spec.rb` (create the file if it does not exist):

```ruby
# frozen_string_literal: true

RSpec.describe JobRun do
  describe "state machine" do
    let(:job_run) { create(:job_run, :pending) }

    it "transitions pending → running on start" do
      job_run.start!
      expect(job_run).to be_running
      expect(job_run.started_at).to be_present
    end

    it "transitions running → canceling on cancel" do
      job_run.update!(status: "running", started_at: Time.zone.now)
      job_run.cancel!
      expect(job_run).to be_canceling
      expect(job_run.cancel_requested_at).to be_present
      expect(job_run.canceled_at).to be_nil
      expect(job_run.completed_at).to be_nil
    end

    it "transitions pending → canceled on cancel (no process running)" do
      job_run.cancel!
      expect(job_run).to be_canceled
      expect(job_run.cancel_requested_at).to be_present
      expect(job_run.canceled_at).to be_present
      expect(job_run.completed_at).to be_present
    end

    it "transitions canceling → canceled on finish_cancel" do
      job_run.update!(status: "canceling", started_at: Time.zone.now, cancel_requested_at: Time.zone.now)
      job_run.finish_cancel!
      expect(job_run).to be_canceled
      expect(job_run.canceled_at).to be_present
      expect(job_run.completed_at).to be_present
    end

    it "does not allow error from terminal states" do
      job_run.update!(status: "completed", started_at: Time.zone.now, completed_at: Time.zone.now)
      expect { job_run.error! }.to raise_error(StateMachines::InvalidTransition)
    end

    it "allows error from canceling (e.g. cancel job crashed)" do
      job_run.update!(status: "canceling", started_at: Time.zone.now, cancel_requested_at: Time.zone.now)
      job_run.error!(error_class: "RuntimeError", error_message: "boom")
      expect(job_run).to be_errored
    end

    it "marks cancelable? for pending and running, not for canceling" do
      expect(build(:job_run, status: "pending")).to be_cancelable
      expect(build(:job_run, status: "running")).to be_cancelable
      expect(build(:job_run, status: "canceling")).not_to be_cancelable
    end
  end
end
```

- [ ] **Step 2: Run tests — verify they fail**

Run: `docker compose exec app bundle exec rspec spec/models/job_run_spec.rb`

Expected: failures for `canceling` state / `finish_cancel!` event not defined.

- [ ] **Step 3: Update the state machine module**

Replace the contents of `app/models/concerns/job_runs/state_machine.rb` with:

```ruby
# frozen_string_literal: true

module JobRuns
  module StateMachine
    extend ActiveSupport::Concern

    included do
      scope :pending,   -> { with_status(:pending) }
      scope :running,   -> { with_status(:running) }
      scope :canceling, -> { with_status(:canceling) }
      scope :completed, -> { with_status(:completed) }
      scope :failed,    -> { with_status(:failed) }
      scope :canceled,  -> { with_status(:canceled) }
      scope :errored,   -> { with_status(:errored) }

      state_machine :status, initial: :pending do
        state :pending
        state :running
        state :canceling
        state :completed
        state :failed
        state :canceled
        state :errored

        event :start do
          transition pending: :running
        end

        event :tick do
          transition running: :running
        end

        event :complete do
          transition running: :completed
        end

        event :mark_failed do
          transition running: :failed
        end

        event :cancel do
          transition pending: :canceled
          transition running: :canceling
        end

        event :finish_cancel do
          transition canceling: :canceled
        end

        event :error do
          transition [:pending, :running, :canceling] => :errored
        end

        before_transition on: :start do |job_run|
          job_run.started_at = Time.zone.now
        end

        before_transition to: [:completed, :failed, :canceled, :errored] do |job_run|
          job_run.completed_at ||= Time.zone.now
        end

        before_transition on: :cancel do |job_run|
          job_run.cancel_requested_at ||= Time.zone.now
        end

        before_transition to: :canceled do |job_run|
          at = Time.zone.now
          job_run.cancel_requested_at ||= at
          job_run.canceled_at ||= at
        end

        before_transition on: :tick do |job_run, transition|
          kwargs = transition.args.first || {}

          job_run.bytes_copied = kwargs[:bytes_copied]
          job_run.progress = kwargs[:progress]
          job_run.speed = kwargs[:speed]
          job_run.remaining_time = kwargs[:remaining_time]
        end

        before_transition on: :error do |job_run, transition|
          kwargs = transition.args.first || {}

          job_run.error_class = kwargs[:error_class] if kwargs.key?(:error_class)
          job_run.error_message = kwargs[:error_message] if kwargs.key?(:error_message)
        end

        after_transition on: :start do |job_run|
          next unless Configuration.get("streaming")

          JobRuns::BroadcastService.broadcast_started(job_run)
        end

        after_transition on: :tick do |job_run|
          next unless Configuration.get("streaming")

          JobRuns::BroadcastService.broadcast_progress(job_run)
        end

        after_transition on: [:complete, :mark_failed, :finish_cancel, :error] do |job_run, transition|
          next unless Configuration.get("streaming")

          JobRuns::BroadcastService.broadcast_complete(job_run, from: transition.from)
        end
      end
    end
  end
end
```

Also update `app/models/job_run.rb`:

```ruby
def cancelable?
  pending? || running?
end

def deletable?
  completed? || failed? || canceled? || errored?
end
```

(no functional change to `deletable?`, only confirming `canceling` is not deletable).

- [ ] **Step 4: Run tests — verify they pass**

Run: `docker compose exec app bundle exec rspec spec/models/job_run_spec.rb`

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add app/models/concerns/job_runs/state_machine.rb app/models/job_run.rb spec/models/job_run_spec.rb
git commit -m "Add canceling state and finish_cancel event to JobRun state machine"
```

---

## Task 3: Move notifications into `after_commit` callbacks

**Why:** Today notifications are enqueued from `JobRuns::ExecuteService` with `wait: 5.seconds` to dodge "uncommitted transaction" races. After this refactor, notifications belong with the state transitions, not the executor. `after_commit` runs after the DB transaction commits, so `Notifications::SendJob.perform_later` will see the row in its committed state and the artificial delay disappears.

**Files:**
- Modify: `app/models/job_run.rb`
- Test: `spec/models/job_run_spec.rb`

**Design:**
- A single `after_commit` on `JobRun` inspects `saved_change_to_status?` and the new status, then fires the matching notification event.
- Events: `start`, `success`, `failure`. Cancellation does *not* fire (matches current behavior — confirmed during brainstorming).
- The actual scheduling logic moves into a private helper or stays in `enqueue_notifications` on the model. I keep it on the model to centralize the side effect.

- [ ] **Step 1: Write failing tests**

Add to `spec/models/job_run_spec.rb`:

```ruby
describe "notifications" do
  let(:user) { create(:user) }
  let(:job) { create(:job, user:) }
  let!(:notification) { create(:notification, user:) }
  let!(:job_notification) { create(:job_notification, job:, notification:) }

  let(:job_run) { create(:job_run, :pending, user:, job:) }

  before do
    allow(Configuration).to receive(:get).and_call_original
    allow(Configuration).to receive(:get).with("notifications").and_return(true)
  end

  it "enqueues a start notification on start" do
    expect { job_run.start! }
      .to have_enqueued_job(Notifications::SendJob)
      .with(job_notification.id, job_run.id, "start")
  end

  it "enqueues a success notification on complete" do
    job_run.update!(status: "running", started_at: Time.zone.now)
    expect { job_run.complete! }
      .to have_enqueued_job(Notifications::SendJob)
      .with(job_notification.id, job_run.id, "success")
  end

  it "enqueues a failure notification on mark_failed" do
    job_run.update!(status: "running", started_at: Time.zone.now)
    expect { job_run.mark_failed! }
      .to have_enqueued_job(Notifications::SendJob)
      .with(job_notification.id, job_run.id, "failure")
  end

  it "enqueues a failure notification on error" do
    expect { job_run.error!(error_class: "RuntimeError", error_message: "boom") }
      .to have_enqueued_job(Notifications::SendJob)
      .with(job_notification.id, job_run.id, "failure")
  end

  it "does not enqueue a notification on cancel" do
    job_run.update!(status: "running", started_at: Time.zone.now)
    expect { job_run.cancel! }.not_to have_enqueued_job(Notifications::SendJob)
  end

  it "does not enqueue a notification on finish_cancel" do
    job_run.update!(status: "canceling", started_at: Time.zone.now, cancel_requested_at: Time.zone.now)
    expect { job_run.finish_cancel! }.not_to have_enqueued_job(Notifications::SendJob)
  end

  it "does not enqueue when notifications are disabled" do
    allow(Configuration).to receive(:get).with("notifications").and_return(false)
    expect { job_run.start! }.not_to have_enqueued_job(Notifications::SendJob)
  end
end
```

- [ ] **Step 2: Run tests — verify they fail**

Run: `docker compose exec app bundle exec rspec spec/models/job_run_spec.rb -e notifications`

Expected: jobs not enqueued (no notification logic yet outside the executor).

- [ ] **Step 3: Add `after_commit` notification logic to `JobRun`**

Edit `app/models/job_run.rb` — add inside the class, *after* the existing associations:

```ruby
NOTIFICATION_EVENTS = {
  "running" => "start",
  "completed" => "success",
  "failed" => "failure",
  "errored" => "failure",
}.freeze

after_commit :enqueue_status_notifications, on: [:create, :update]

# ...

private

def enqueue_status_notifications
  return unless Configuration.get("notifications")
  return unless saved_change_to_status?

  event = NOTIFICATION_EVENTS[status]
  return unless event

  job.job_notifications.find_each do |job_notification|
    Notifications::SendJob.perform_later(job_notification.id, id, event)
  end
end
```

(Note: the previous `set(wait: 5.seconds)` is intentionally dropped — `after_commit` ensures the transaction is already committed.)

- [ ] **Step 4: Run tests — verify they pass**

Run: `docker compose exec app bundle exec rspec spec/models/job_run_spec.rb -e notifications`

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add app/models/job_run.rb spec/models/job_run_spec.rb
git commit -m "Move notification dispatch from executor to JobRun after_commit"
```

---

## Task 4: Simplify `Processes::ExecuteService`

**Files:**
- Modify: `app/services/processes/execute_service.rb`
- Modify: `spec/services/processes/execute_service_spec.rb`

**Design:**
- The service becomes a dumb runner: spawn the command in its own process group, persist the pid on the JobRun, yield the output IO to the block, return a `Result` with the exit status.
- No monitor thread. No heartbeat. No DB polling for `cancel_requested_at`. No `canceled` field on the result.
- Callers are responsible for: (a) checking `job_run.canceling?` between phases, and (b) interpreting the exit status (a SIGTERMed rsync looks like a failed rsync to this service).

- [ ] **Step 1: Update tests first**

Open `spec/services/processes/execute_service_spec.rb`. Remove any heartbeat- or cancellation-related expectations. Keep tests that:
- spawn `/bin/echo hello`, expect the block to receive an IO yielding "hello\n", and the result exit status `success?` to be true,
- spawn `/bin/sh -c 'exit 7'`, expect `result.exit_status.exitstatus == 7`,
- spawn a command and assert `job_run.reload.pid` is set to a positive integer while the block runs.

```ruby
# frozen_string_literal: true

RSpec.describe Processes::ExecuteService do
  let(:job_run) { create(:job_run, :pending) }

  it "yields the output IO and returns a successful exit status" do
    output = +""
    result = described_class.new("/bin/echo hello", job_run).call do |io|
      output << io.read
    end

    expect(output).to eq("hello\n")
    expect(result.exit_status).to be_success
  end

  it "returns the non-zero exit status" do
    result = described_class.new("/bin/sh -c 'exit 7'", job_run).call do |io|
      io.read
    end

    expect(result.exit_status.exitstatus).to eq(7)
  end

  it "records the pid on the job_run" do
    captured_pid = nil
    described_class.new("/bin/sh -c 'sleep 0.1'", job_run).call do |io|
      captured_pid = job_run.reload.pid
      io.read
    end

    expect(captured_pid).to be_a(Integer).and be_positive
  end
end
```

- [ ] **Step 2: Run tests — verify they fail or pass against old interface**

Run: `docker compose exec app bundle exec rspec spec/services/processes/execute_service_spec.rb`

Expected: some pass with the old service, but the new Result shape (no `canceled` field) breaks tests if you have any. Use this baseline to confirm the test surface is what you want.

- [ ] **Step 3: Replace `Processes::ExecuteService`**

```ruby
# frozen_string_literal: true

module Processes
  class ExecuteService < ApplicationService
    Result = Data.define(:exit_status)

    attr_reader :command, :job_run

    def initialize(command, job_run)
      super()

      @command = command
      @job_run = job_run
    end

    # Spawns the command in a new process group, records the pid on job_run,
    # and yields stdout/stderr (merged) to the block as an IO. Returns the
    # exit status wrapped in a Result.
    #
    # Cancellation is handled externally: JobRuns::CancelJob signals the pid;
    # this service merely waits for the process to exit and reports the
    # status. Callers must distinguish "exited non-zero because of SIGTERM"
    # from "exited non-zero because of an error" themselves by checking
    # job_run.canceling? after the call.
    def call
      Open3.popen2e(command, pgroup: true) do |_stdin, output, wait_thr|
        job_run.update!(pid: wait_thr.pid)

        begin
          yield output
        ensure
          # Ensure wait_thr reaps even if the block raised
        end

        Result.new(exit_status: wait_thr.value)
      end
    ensure
      # Clear the pid once the process has exited so a later cancel job
      # does not signal a recycled PID. Best-effort: the executor will also
      # set the pid explicitly when spawning the next phase.
      job_run.update_column(:pid, nil) if job_run.persisted?
    end
  end
end
```

- [ ] **Step 4: Run tests**

Run: `docker compose exec app bundle exec rspec spec/services/processes/execute_service_spec.rb`

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add app/services/processes/execute_service.rb spec/services/processes/execute_service_spec.rb
git commit -m "Simplify Processes::ExecuteService: drop monitor thread and heartbeat"
```

---

## Task 5: Update `Rsync::ExecuteService` to drop heartbeat

**Files:**
- Modify: `app/services/rsync/execute_service.rb`
- Modify: `spec/services/rsync/execute_service_spec.rb` (remove heartbeat expectations if any)

- [ ] **Step 1: Update tests**

Open `spec/services/rsync/execute_service_spec.rb`, remove any references to `heartbeat_interval` or `with_configuration "jobs.heartbeat_interval"`.

- [ ] **Step 2: Replace service**

```ruby
# frozen_string_literal: true

module Rsync
  class ExecuteService < ApplicationService
    Result = Processes::ExecuteService::Result

    attr_reader :command, :job_run

    def initialize(command, job_run)
      super()

      @command = command
      @job_run = job_run
    end

    def call(&block)
      Processes::ExecuteService.new(command, job_run).call do |output|
        buffer = +""

        loop do
          chunk = output.readpartial(4096)

          Rails.logger.debug { chunk }

          buffer << chunk

          lines = buffer.split(/(?<=[\r\n])/)
          buffer = lines.last&.match?(/[\r\n]\z/) ? +"" : (lines.pop || +"")

          lines.each { |line| block&.call(line) }
        rescue EOFError
          break
        end

        block&.call(buffer) if buffer.present?
      end
    end
  end
end
```

- [ ] **Step 3: Run tests**

Run: `docker compose exec app bundle exec rspec spec/services/rsync/execute_service_spec.rb`

Expected: all green.

- [ ] **Step 4: Commit**

```bash
git add app/services/rsync/execute_service.rb spec/services/rsync/execute_service_spec.rb
git commit -m "Drop heartbeat from Rsync::ExecuteService"
```

---

## Task 6: Rewrite `Hooks::ExecuteService`

**Files:**
- Modify: `app/services/hooks/execute_service.rb`
- Modify: `spec/services/hooks/execute_service_spec.rb`

**Design:**
- The service runs *one* hook process. It writes the per-hook status, exit_status, error_class, error_message columns on the JobRun directly (the new columns from migration `20260525072632`).
- The attachment slot (e.g. `pre_hook_output`) is always attached, even on exception, so logs are not lost.
- The result returned to the caller is reduced to `{ success: Boolean, exit_status: Integer | nil }` — error metadata is already persisted.

- [ ] **Step 1: Write failing tests**

```ruby
# spec/services/hooks/execute_service_spec.rb (rewrite)
RSpec.describe Hooks::ExecuteService do
  let(:job_run) { create(:job_run, :running) }
  let(:hook) { create(:hook, hook_type: "pre", command: command, enabled: true) }

  subject(:service) { described_class.new(hook, job_run:) }

  context "when the hook exits zero" do
    let(:command) { "/bin/sh -c 'echo ok'" }

    it "records success and attaches the log" do
      result = service.call

      expect(result[:success]).to be true
      expect(result[:exit_status]).to eq 0

      job_run.reload

      expect(job_run.pre_hook_status).to eq("success")
      expect(job_run.pre_hook_exit_status).to eq(0)
      expect(job_run.pre_hook_error_class).to be_nil
      expect(job_run.pre_hook_error_message).to be_nil
      expect(job_run.pre_hook_output).to be_attached
    end
  end

  context "when the hook exits non-zero" do
    let(:command) { "/bin/sh -c 'exit 3'" }

    it "records failure and attaches the log" do
      result = service.call

      expect(result[:success]).to be false
      expect(result[:exit_status]).to eq 3

      job_run.reload

      expect(job_run.pre_hook_status).to eq("failed")
      expect(job_run.pre_hook_exit_status).to eq(3)
      expect(job_run.pre_hook_output).to be_attached
    end
  end

  context "when spawning the hook raises" do
    let(:command) { "/bin/sh -c 'echo ok'" }

    before do
      allow(Processes::ExecuteService).to receive(:new).and_raise(Errno::ENOENT, "no such file")
    end

    it "records the error class and message, and does not raise" do
      result = service.call

      expect(result[:success]).to be false
      expect(result[:exit_status]).to be_nil

      job_run.reload

      expect(job_run.pre_hook_status).to eq("errored")
      expect(job_run.pre_hook_error_class).to eq("Errno::ENOENT")
      expect(job_run.pre_hook_error_message).to include("no such file")
    end
  end
end
```

- [ ] **Step 2: Run tests — verify they fail**

Run: `docker compose exec app bundle exec rspec spec/services/hooks/execute_service_spec.rb`

Expected: failures — service returns different shape, columns not set.

- [ ] **Step 3: Rewrite `Hooks::ExecuteService`**

```ruby
# frozen_string_literal: true

module Hooks
  class ExecuteService < ApplicationService
    attr_reader :hook, :job_run

    def initialize(hook, job_run:)
      super()

      @hook = hook
      @job_run = job_run
    end

    def call
      full_command = [hook.command, interpolate(hook.arguments)].compact_blank.join(" ")

      Tempfile.create(["hook_#{hook.hook_type}", ".log"]) do |file|
        begin
          result = Processes::ExecuteService.new(full_command, job_run).call do |output|
            file.write(output.read)
          end

          attach_output(file)

          persist_status(
            status: result.exit_status.success? ? "success" : "failed",
            exit_status: result.exit_status.exitstatus,
          )

          { success: result.exit_status.success?, exit_status: result.exit_status.exitstatus }
        rescue StandardError => e
          attach_output(file)

          persist_status(status: "errored", error_class: e.class.name, error_message: e.message)

          { success: false, exit_status: nil }
        end
      end
    end

    private

    def attach_output(file)
      attachment = job_run.public_send(:"#{hook.hook_type}_hook_output")
      return if attachment.attached?

      file.rewind
      attachment.attach(
        io: file,
        filename: "hook_#{hook.hook_type}_#{job_run.sequence}.log",
        content_type: "text/plain",
      )
    end

    def persist_status(status:, exit_status: nil, error_class: nil, error_message: nil)
      job_run.update!(
        :"#{hook.hook_type}_hook_status" => status,
        :"#{hook.hook_type}_hook_exit_status" => exit_status,
        :"#{hook.hook_type}_hook_error_class" => error_class,
        :"#{hook.hook_type}_hook_error_message" => error_message,
      )
    end

    def interpolate(template)
      return if template.blank?

      job = job_run.job

      substitutions = {
        "{job_id}" => job.id,
        "{job_name}" => job.name,
        "{trigger}" => job_run.trigger,
        "{job_sequence}" => job_run.sequence.to_s,
        "{source_id}" => job.source_repository.id,
        "{source_name}" => job.source_repository.name,
        "{destination_id}" => job.destination_repository.id,
        "{destination_name}" => job.destination_repository.name,
        "{started_at}" => job_run.started_at&.iso8601,
        "{user_id}" => job_run.user.id,
        "{user_name}" => job_run.user.full_name,
        "{completed_at}" => job_run.completed_at&.iso8601,
        "{duration}" => job_run.duration&.to_s,
        "{status}" => job_run.status,
        "{error}" => ([job_run.error_class, job_run.error_message].compact.join(": ") if job_run.error_class.present?),
      }

      template.gsub(/\{[^}]+\}/) { |match| substitutions.fetch(match, match) }
    end
  end
end
```

- [ ] **Step 4: Run tests**

Run: `docker compose exec app bundle exec rspec spec/services/hooks/execute_service_spec.rb`

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add app/services/hooks/execute_service.rb spec/services/hooks/execute_service_spec.rb
git commit -m "Persist per-hook status and always attach hook output"
```

---

## Task 7: Add `JobRuns::CancelJob`

**Files:**
- Create: `app/jobs/job_runs/cancel_job.rb`
- Create: `spec/jobs/job_runs/cancel_job_spec.rb`

**Design:**
- The job's sole responsibility is to SIGTERM the recorded pid (process group, matching how the executor spawns).
- It does *not* transition state. The executor owns `canceling → canceled`.
- It rescues `Errno::ESRCH` (process already exited) and `Errno::EPERM` (shouldn't happen with our single-uid container, but defend against it). If `pid` is nil, the job is a no-op — the next executor checkpoint will catch the `canceling` state.
- Queued to the `workers` queue so it executes on the worker host (same kernel where the rsync pid lives).

- [ ] **Step 1: Write failing tests**

```ruby
# spec/jobs/job_runs/cancel_job_spec.rb
RSpec.describe JobRuns::CancelJob do
  subject(:job) { described_class }

  let(:job_run) { create(:job_run, :running, pid: 99_999) }

  it "is queued on the workers queue" do
    expect(described_class.new.queue_name).to eq("workers")
  end

  it "sends SIGTERM to the negative pid (process group)" do
    expect(Process).to receive(:kill).with("TERM", -99_999)

    described_class.perform_now(job_run)
  end

  it "is a no-op when pid is nil" do
    job_run.update_column(:pid, nil)

    expect(Process).not_to receive(:kill)

    described_class.perform_now(job_run)
  end

  it "is a no-op when the process is already gone" do
    allow(Process).to receive(:kill).with("TERM", -99_999).and_raise(Errno::ESRCH)

    expect { described_class.perform_now(job_run) }.not_to raise_error
  end

  it "is a no-op when the job_run is no longer canceling/running" do
    job_run.update!(status: "completed", started_at: 1.minute.ago, completed_at: Time.zone.now)

    expect(Process).not_to receive(:kill)

    described_class.perform_now(job_run)
  end
end
```

- [ ] **Step 2: Run tests — verify they fail**

Run: `docker compose exec app bundle exec rspec spec/jobs/job_runs/cancel_job_spec.rb`

Expected: file not found / class not defined.

- [ ] **Step 3: Implement the job**

```ruby
# frozen_string_literal: true

module JobRuns
  class CancelJob < ApplicationJob
    queue_as :workers

    def perform(job_run)
      job_run.reload

      return unless job_run.running? || job_run.canceling?

      pid = job_run.pid
      return if pid.nil?

      Process.kill("TERM", -pid)
    rescue Errno::ESRCH, Errno::EPERM
      # Process is gone or unsignalable — the executor's next checkpoint will
      # observe job_run.canceling? and transition to :canceled itself.
      nil
    end
  end
end
```

- [ ] **Step 4: Run tests**

Run: `docker compose exec app bundle exec rspec spec/jobs/job_runs/cancel_job_spec.rb`

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add app/jobs/job_runs/cancel_job.rb spec/jobs/job_runs/cancel_job_spec.rb
git commit -m "Add JobRuns::CancelJob to signal recorded pid asynchronously"
```

---

## Task 8: Rewrite `JobRuns::CancelService`

**Files:**
- Modify: `app/services/job_runs/cancel_service.rb`
- Modify: `spec/services/job_runs/cancel_service_spec.rb`

**Design:**
- For `pending` runs: synchronously transition to `canceled` (no process to kill).
- For `running` runs: synchronously transition to `canceling`, then `perform_later` `JobRuns::CancelJob`.
- For `canceling` (already in flight) or terminal runs: return `{ success: false }`.
- Wrap the read-and-transition in `with_lock` to close the race window with the executor's `start!`.

- [ ] **Step 1: Update tests**

```ruby
# spec/services/job_runs/cancel_service_spec.rb
RSpec.describe JobRuns::CancelService do
  subject(:service) { described_class.new(job_run) }

  let(:user) { create(:user) }

  describe "#call" do
    context "when the job run is pending" do
      let(:job_run) { create(:job_run, :pending, user:) }

      it "transitions immediately to canceled" do
        result = service.call

        expect(result[:success]).to be true

        job_run.reload
        expect(job_run).to be_canceled
        expect(job_run.cancel_requested_at).to be_present
        expect(job_run.canceled_at).to be_present
      end

      it "does not enqueue CancelJob" do
        expect { service.call }.not_to have_enqueued_job(JobRuns::CancelJob)
      end
    end

    context "when the job run is running" do
      let(:job_run) { create(:job_run, :running, user:, pid: 12_345) }

      it "transitions to canceling and enqueues CancelJob" do
        expect { service.call }.to have_enqueued_job(JobRuns::CancelJob).with(job_run)

        job_run.reload
        expect(job_run).to be_canceling
        expect(job_run.cancel_requested_at).to be_present
      end
    end

    context "when the job run is already canceling" do
      let(:job_run) { create(:job_run, :running, user:) }

      before { job_run.update!(status: "canceling", cancel_requested_at: Time.zone.now) }

      it "returns failure and does not enqueue" do
        expect(service.call[:success]).to be false
        expect(JobRuns::CancelJob).not_to have_been_enqueued
      end
    end

    context "when the job run is terminal" do
      let(:job_run) { create(:job_run, :completed, user:) }

      it "returns failure" do
        expect(service.call[:success]).to be false
      end
    end
  end
end
```

(The `:running` factory trait must exist — confirm in `spec/factories/job_runs.rb` and add if missing.)

- [ ] **Step 2: Run tests — verify they fail**

Run: `docker compose exec app bundle exec rspec spec/services/job_runs/cancel_service_spec.rb`

Expected: failures around `canceling` status and CancelJob enqueuement.

- [ ] **Step 3: Rewrite `JobRuns::CancelService`**

```ruby
# frozen_string_literal: true

module JobRuns
  class CancelService < ApplicationService
    attr_reader :job_run

    def initialize(job_run)
      super()

      @job_run = job_run
    end

    def call
      return { success: false } unless job_run.cancelable?

      enqueue_cancel_job = false

      job_run.with_lock do
        job_run.reload

        return { success: false } unless job_run.cancelable?

        if job_run.pending?
          job_run.cancel!
        else
          # running -> canceling
          job_run.cancel!
          enqueue_cancel_job = true
        end
      end

      JobRuns::CancelJob.perform_later(job_run) if enqueue_cancel_job

      { success: true }
    end
  end
end
```

- [ ] **Step 4: Run tests**

Run: `docker compose exec app bundle exec rspec spec/services/job_runs/cancel_service_spec.rb`

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add app/services/job_runs/cancel_service.rb spec/services/job_runs/cancel_service_spec.rb
git commit -m "Synchronously transition to canceling and enqueue CancelJob"
```

---

## Task 9: Rewrite `JobRuns::ExecuteService` as linear phases with checkpoints

**Files:**
- Modify: `app/services/job_runs/execute_service.rb`
- Modify: `spec/services/job_runs/execute_service_spec.rb`

**Design (executor flow):**
1. Read configuration once into local flags: `hooks_enabled = Configuration.get("hooks")`, `streaming_enabled = Configuration.get("streaming")`.
2. `job_run.with_lock { return unless job_run.pending?; job_run.start! }`.
3. **Pre-hook phase** (if `hooks_enabled` and `job.pre_hook&.enabled?`):
   - Run via `Hooks::ExecuteService`. The hook service writes its own status columns and attaches its log.
   - Track `pre_hook_succeeded = result[:success]`.
4. **Checkpoint:** `return finalize_cancel! if job_run.reload.canceling?`.
5. **rsync phase** (only if `pre_hook_succeeded` is true or pre-hook was absent):
   - Build the command, open the tempfile, stream lines with progress parsing, attach output.
   - `rsync_succeeded = exit_status.success?` (only when not canceling).
6. **Checkpoint:** `return finalize_cancel! if job_run.reload.canceling?`.
7. **Post-hook phase** (if `hooks_enabled` and `job.post_hook&.enabled?` and the pre-hook didn't fail-and-skip-rsync):
   - Same as pre-hook. `post_hook_succeeded = result[:success]`.
   - Always runs after rsync, regardless of rsync result, as long as we got there (pre-hook didn't fail).
8. **Checkpoint:** `return finalize_cancel! if job_run.reload.canceling?`.
9. **Compute terminal state from internal flags:**
   - If pre-hook ran and failed → `mark_failed!`.
   - Elsif rsync ran and failed → `mark_failed!`.
   - Elsif post-hook ran and failed → `mark_failed!`.
   - Else → `complete!`.
10. **Success/failure hook phase** (based on the terminal state). Runs but does *not* affect terminal state — its own per-hook status columns capture what happened.
11. Outer rescue: `StandardError` → `job_run.error!(error_class:, error_message:)` and ensure any in-flight tempfile is attached to `job_run.output` via `attach_log`.

**Key invariants:**
- Each phase clears `job_run.pid` after the process exits (already done in `Processes::ExecuteService`).
- Terminal state is set exactly once.
- `finalize_cancel!` calls `job_run.finish_cancel!` and returns.
- Notifications are *not* enqueued from here — the model's `after_commit` does it.

- [ ] **Step 1: Update tests**

The current `spec/services/job_runs/execute_service_spec.rb` has good coverage. Update it to:
- Remove expectations about `enqueue_notifications` from this service (now in model `after_commit`).
- Add expectations for the new flow:
  - Pre-hook failure ⇒ rsync is *not* called, state is `failed`, failure hook runs.
  - rsync failure ⇒ post-hook *is* called, state is `failed`, failure hook runs.
  - Post-hook failure ⇒ state is `failed`, failure hook runs.
  - Mid-flow cancellation (set `job_run.status = "canceling"` between phases via a `before(:each)` stub on `reload`) ⇒ state ends `canceled`, no further phases run.
  - Output log always attached, even when `Rsync::CommandService` raises.

Show one concrete example:

```ruby
context "when the pre-hook fails" do
  let(:pre_hook) { create(:hook, hook_type: "pre", enabled: true) }
  let(:job) { create(:job, user:, pre_hook:) }

  before do
    allow(Hooks::ExecuteService).to receive(:new).and_wrap_original do |orig, *args, **kwargs|
      hook = args.first
      service = orig.call(hook, **kwargs)
      if hook.hook_type == "pre"
        allow(service).to receive(:call).and_return({ success: false, exit_status: 3 }).and_wrap_original do
          job_run.update!(pre_hook_status: "failed", pre_hook_exit_status: 3)
          { success: false, exit_status: 3 }
        end
      end
      service
    end
  end

  it "marks the run as failed and skips rsync" do
    service.call

    job_run.reload

    expect(job_run).to be_failed
    expect(command_service).not_to have_received(:call)
  end
end
```

(Repeat the pattern for the other scenarios — keep the existing scaffold of `instance_double(Rsync::ExecuteService)` etc., but stop mocking `enqueue_notifications`.)

- [ ] **Step 2: Run tests — verify they fail**

Run: `docker compose exec app bundle exec rspec spec/services/job_runs/execute_service_spec.rb`

Expected: failures across the board — old service shape doesn't match new tests.

- [ ] **Step 3: Rewrite `JobRuns::ExecuteService`**

```ruby
# frozen_string_literal: true

module JobRuns
  class ExecuteService < ApplicationService
    attr_reader :job_run, :job

    def initialize(job_run)
      super()

      @job_run = job_run
      @job = job_run.job
    end

    def call
      @hooks_enabled = Configuration.get("hooks")
      @streaming_enabled = Configuration.get("streaming")

      job_run.with_lock do
        job_run.reload
        return unless job_run.pending?

        job_run.start!
      end

      Rails.logger.info "[#{job.id}] Executing job #{job.name}"

      pre_ok = run_pre_hook
      return finalize_cancel if canceled_mid_flow?

      rsync_ok = pre_ok ? run_rsync : nil
      return finalize_cancel if canceled_mid_flow?

      post_ok = pre_ok ? run_post_hook : nil
      return finalize_cancel if canceled_mid_flow?

      terminal = compute_terminal_state(pre_ok:, rsync_ok:, post_ok:)
      finalize_terminal(terminal)

      run_outcome_hook(terminal)
    rescue StandardError => e
      # rsync's own log is attached inside run_rsync (both happy path and
      # its rescue clause), and each hook attaches its own log. Nothing to
      # salvage here.
      job_run.error!(error_class: e.class.name, error_message: e.message) if job_run.running? || job_run.canceling?
    end

    private

    # ------------------------------------------------------------------------
    # Phase runners
    # ------------------------------------------------------------------------

    def run_pre_hook
      return true unless @hooks_enabled

      hook = job.pre_hook
      return true unless hook&.enabled?

      result = Hooks::ExecuteService.new(hook, job_run:).call
      result[:success]
    end

    def run_rsync
      command = Rsync::CommandService.new(job:).call

      Tempfile.create(["job_run_#{job.name.parameterize(separator: '_')}_#{job_run.sequence}", ".log"]) do |file|
        @rsync_tempfile = file
        file.write("#{command}\n")
        last_status_line = nil

        begin
          result = Rsync::ExecuteService.new(command, job_run).call do |line|
            status = Rsync::Progress.new(line) if job.opt_progress || job.opt_progress2

            if @streaming_enabled
              payload = { type: status&.bytes ? "status" : "log", content: line }
              ActionCable.server.broadcast("job_run_logs_#{job_run.id}", payload)
            end

            if job.opt_progress2 && status&.bytes
              job_run.tick!(bytes_copied: status.bytes, progress: status.progress, speed: status.speed, remaining_time: status.remaining_time)
              last_status_line = line
            else
              file.write(line)
            end
          end

          file.write(last_status_line) if last_status_line

          attach_rsync_log(file)

          exit_status = result.exit_status
          Rails.logger.info { "[#{job.id}] rsync exited: #{exit_status.exitstatus || "signal #{exit_status.termsig}"}" }

          exit_status.success?
        rescue StandardError
          attach_rsync_log(file)
          raise
        end
      end
    ensure
      @rsync_tempfile = nil
    end

    def attach_rsync_log(file)
      return if job_run.output.attached?

      file.rewind
      job_run.output.attach(
        io: file,
        filename: "job_run_#{job_run.sequence}.log",
        content_type: "text/plain",
      )
    rescue StandardError
      nil
    end

    def run_post_hook
      return true unless @hooks_enabled

      hook = job.post_hook
      return true unless hook&.enabled?

      result = Hooks::ExecuteService.new(hook, job_run:).call
      result[:success]
    end

    def run_outcome_hook(terminal)
      return unless @hooks_enabled

      hook_type = terminal == :completed ? :success_hook : :failure_hook
      hook = job.send(hook_type)
      return unless hook&.enabled?

      Hooks::ExecuteService.new(hook, job_run:).call
    end

    # ------------------------------------------------------------------------
    # State transitions
    # ------------------------------------------------------------------------

    def canceled_mid_flow?
      job_run.reload.canceling?
    end

    def finalize_cancel
      job_run.finish_cancel!
      run_outcome_hook(:failed) # cancel routes to failure-hook semantics
    end

    def compute_terminal_state(pre_ok:, rsync_ok:, post_ok:)
      if pre_ok == false
        :failed
      elsif rsync_ok == false
        :failed
      elsif post_ok == false
        :failed
      else
        :completed
      end
    end

    def finalize_terminal(terminal)
      case terminal
      when :completed then job_run.complete!
      when :failed    then job_run.mark_failed!
      end
    end

  end
end
```

**Decision note for the implementer:** the outline in the brainstorming session said "transition to failed immediately when each phase fails." This implementation instead defers the terminal transition until after post-hook completes, then computes it from internal flags. Reason: it avoids `failed → failed` re-entry on the state machine and keeps "exactly one terminal transition" as a hard invariant. Per-hook status columns still capture each phase's outcome independently, so the UI / failure hook can still distinguish "pre-hook failed" from "rsync failed."

If the user explicitly wants immediate transitions per phase, change `compute_terminal_state` into inline transitions guarded by `if job_run.running?` — but raise this with them before deviating.

- [ ] **Step 4: Run tests**

Run: `docker compose exec app bundle exec rspec spec/services/job_runs/execute_service_spec.rb`

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add app/services/job_runs/execute_service.rb spec/services/job_runs/execute_service_spec.rb
git commit -m "Rewrite JobRuns::ExecuteService as linear phases with cancellation checkpoints"
```

---

## Task 10: Rewrite `Jobs::TerminateStuckJobsService` as PID-liveness reaper

**Files:**
- Modify: `app/services/jobs/terminate_stuck_jobs_service.rb`
- Modify: `spec/services/jobs/terminate_stuck_jobs_service_spec.rb`
- Modify: `app/jobs/scheduler_job.rb` (queue routing — see Task 12)

**Design:**
- Query `JobRun.where(status: ["running", "canceling"])`.
- For each row:
  - If `pid` is present: check `Process.kill(0, pid)` (rescue `Errno::ESRCH` → dead, `Errno::EPERM` → alive). Use the negative pid (process group) consistent with how the executor spawns.
  - If `pid` is nil and `updated_at < grace_period.ago` (configurable, e.g. 30 s): treat as stuck (executor died between spawning phases).
  - Otherwise: skip (alive or in grace window).
- Stuck reaping:
  - `running` rows → `error!(error_class: "Stuck", error_message: "Worker process gone")`.
  - `canceling` rows → `finish_cancel!` (SIGTERM presumably worked, executor just didn't finalize).
- Also reap `pending` rows older than `pending_threshold` (keep existing behavior).
- The reaper must run on the worker container — see Task 12.

**Config:** Drop `jobs.heartbeat_interval`. Repurpose `jobs.stuck_threshold` as the grace period for `pid IS NULL` rows. (Or rename to `jobs.reaper_grace_seconds` — call this out to the user before renaming, since config keys are user-visible.)

- [ ] **Step 1: Update tests**

```ruby
# spec/services/jobs/terminate_stuck_jobs_service_spec.rb
RSpec.describe Jobs::TerminateStuckJobsService do
  subject(:service) { described_class }

  with_configuration "jobs.stuck_threshold" => 30

  describe ".call" do
    context "with a running job whose pid is dead" do
      let!(:job_run) { create(:job_run, :running, pid: 99_999) }

      before do
        allow(Process).to receive(:kill).with(0, -99_999).and_raise(Errno::ESRCH)
      end

      it "marks the job_run as errored" do
        service.call
        expect(job_run.reload).to be_errored
        expect(job_run.error_message).to include("Worker")
      end
    end

    context "with a running job whose pid is alive" do
      let!(:job_run) { create(:job_run, :running, pid: 99_999) }

      before do
        allow(Process).to receive(:kill).with(0, -99_999).and_return(1)
      end

      it "does not reap" do
        service.call
        expect(job_run.reload).to be_running
      end
    end

    context "with a running job whose pid is nil and inside grace window" do
      let!(:job_run) { create(:job_run, :running, pid: nil, updated_at: 5.seconds.ago) }

      it "does not reap" do
        service.call
        expect(job_run.reload).to be_running
      end
    end

    context "with a running job whose pid is nil and past grace window" do
      let!(:job_run) { create(:job_run, :running, pid: nil, updated_at: 5.minutes.ago) }

      it "marks the job_run as errored" do
        service.call
        expect(job_run.reload).to be_errored
      end
    end

    context "with a canceling job whose pid is dead" do
      let!(:job_run) { create(:job_run, :running, pid: 99_999) }

      before do
        job_run.update!(status: "canceling", cancel_requested_at: 1.minute.ago)
        allow(Process).to receive(:kill).with(0, -99_999).and_raise(Errno::ESRCH)
      end

      it "transitions canceling → canceled" do
        service.call
        expect(job_run.reload).to be_canceled
      end
    end

    context "with a stuck pending job" do
      let!(:job_run) { create(:job_run, :pending, created_at: 5.minutes.ago) }

      it "marks the job_run as errored" do
        service.call
        expect(job_run.reload).to be_errored
      end
    end
  end
end
```

- [ ] **Step 2: Run tests — verify they fail**

Run: `docker compose exec app bundle exec rspec spec/services/jobs/terminate_stuck_jobs_service_spec.rb`

Expected: failures around PID-liveness logic.

- [ ] **Step 3: Rewrite the service**

```ruby
# frozen_string_literal: true

module Jobs
  class TerminateStuckJobsService < ApplicationService
    def call
      grace = Configuration.get("jobs.stuck_threshold").to_i.seconds
      threshold = grace.ago

      reap_pending(threshold)
      reap_running_or_canceling(threshold)
    end

    private

    def reap_pending(threshold)
      JobRun.pending.where(created_at: ...threshold).find_each do |job_run|
        job_run.error!(error_class: "Stuck", error_message: "Job was not picked up by a worker within the grace period")
      end
    end

    def reap_running_or_canceling(threshold)
      JobRun.where(status: ["running", "canceling"]).find_each do |job_run|
        next unless stuck?(job_run, threshold)

        if job_run.canceling?
          # SIGTERM presumably worked; executor never finalized.
          job_run.finish_cancel!
        else
          job_run.error!(error_class: "Stuck", error_message: "Worker process is no longer alive")
        end
      end
    end

    def stuck?(job_run, threshold)
      if job_run.pid.present?
        process_dead?(job_run.pid)
      else
        # No pid recorded — either between phases or executor died before
        # spawning. Wait for the grace window so we don't reap a healthy
        # row during a brief pid-gap.
        job_run.updated_at < threshold
      end
    end

    def process_dead?(pid)
      Process.kill(0, -pid)
      false
    rescue Errno::ESRCH
      true
    rescue Errno::EPERM
      false # exists but we can't signal it — assume alive
    end
  end
end
```

- [ ] **Step 4: Run tests**

Run: `docker compose exec app bundle exec rspec spec/services/jobs/terminate_stuck_jobs_service_spec.rb`

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add app/services/jobs/terminate_stuck_jobs_service.rb spec/services/jobs/terminate_stuck_jobs_service_spec.rb
git commit -m "Reap stuck job runs via PID-liveness check instead of heartbeats"
```

---

## Task 11: Remove obsolete configuration

**Files:**
- Modify: `config/configurations.yml`
- Modify: `config/locales/configurations/en.yml`
- Modify: `spec/jobs/scheduler_job_spec.rb` (drop `jobs.heartbeat_interval` from `with_configuration`)

- [ ] **Step 1: Remove `jobs.heartbeat_interval` from `config/configurations.yml`**

Delete lines 112–117:

```yaml
- key: jobs.heartbeat_interval
  type: integer
  category: system
  default: 30
  minimum: 1
  maximum:
```

Keep `jobs.stuck_threshold` (now serves as the reaper grace period).

- [ ] **Step 2: Update `config/locales/configurations/en.yml`**

Remove the `heartbeat_interval` description entry. Update `stuck_threshold` description to:

```yaml
stuck_threshold:
  description: Grace period (in seconds) before a job run with no live process is reaped
```

Run: `docker compose exec app bundle exec i18n-tasks normalize` (per CLAUDE.md).

- [ ] **Step 3: Update scheduler spec**

In `spec/jobs/scheduler_job_spec.rb`, remove `"jobs.heartbeat_interval" => 30` from the `with_configuration` line, leaving only `"jobs.stuck_threshold" => 300`.

- [ ] **Step 4: Run relevant tests**

Run: `docker compose exec app bundle exec rspec spec/jobs/scheduler_job_spec.rb`

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add config/configurations.yml config/locales/configurations/en.yml spec/jobs/scheduler_job_spec.rb
git commit -m "Remove jobs.heartbeat_interval configuration"
```

---

## Task 12: Route executor and reaper to the workers queue

**Why:** The PID-liveness check in `Process.kill(0, pid)` only resolves correctly against the host kernel where the rsync process runs. The API container's kernel doesn't know about worker pids. Pin both the executor and the reaper to a `workers` queue that only the worker container consumes.

**Files:**
- Modify: `app/jobs/jobs/execute_job.rb`
- Modify: `app/jobs/scheduler_job.rb` (the scheduler enqueues `TerminateStuckJobsService` — wrap it in a job or call it from a worker-queued recurring task)
- Modify: `config/recurring.yml`

- [ ] **Step 1: Update `Jobs::ExecuteJob` queue**

```ruby
# frozen_string_literal: true

module Jobs
  class ExecuteJob < ApplicationJob
    queue_as :workers

    limits_concurrency to: 1,
                       key: ->(job_run, **) { job_run.job_id },
                       duration: 1.hour

    def perform(job_run)
      JobRuns::ExecuteService.new(job_run).call
    end
  end
end
```

- [ ] **Step 2: Move the reaper into a recurring task on the workers queue**

In `config/recurring.yml`, replace the scheduler invocation of `TerminateStuckJobsService` with a dedicated recurring entry:

```yaml
default: &default
  scheduler:
    class: "SchedulerJob"
    schedule: every minute
  reap_stuck_job_runs:
    command: "Jobs::TerminateStuckJobsService.call"
    queue: workers
    schedule: every minute
  clear_solid_queue_finished_jobs:
    command: "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)"
    schedule: every hour at minute 12
  trim_solid_cable_messages:
    class: "SolidCable::TrimJob"
    schedule: every hour at minute 30
```

And remove the `Jobs::TerminateStuckJobsService.call` line from `app/jobs/scheduler_job.rb` (so the scheduler no longer triggers it from whichever queue it happens to run on).

- [ ] **Step 3: Run job specs**

Run: `docker compose exec app bundle exec rspec spec/jobs/scheduler_job_spec.rb spec/jobs/job_runs/cancel_job_spec.rb`

Expected: all green. Adjust `scheduler_job_spec.rb` to drop expectations about `TerminateStuckJobsService` being called from the scheduler.

- [ ] **Step 4: Verify Solid Queue is configured to process the `workers` queue on the worker container**

Read `config/queue.yml` (or `config/solid_queue.yml`). Confirm there's a worker configuration consuming the `workers` queue. If not, add it — but check with the user before modifying production queue config.

Run: `docker compose exec app cat config/queue.yml`

If the worker config doesn't include `workers`, ask the user how they'd like to route it before proceeding.

- [ ] **Step 5: Commit**

```bash
git add app/jobs/jobs/execute_job.rb app/jobs/scheduler_job.rb config/recurring.yml spec/jobs/scheduler_job_spec.rb
git commit -m "Route executor and reaper to workers queue"
```

---

## Task 13: Full test suite + style checks

**Files:** all touched in previous tasks.

- [ ] **Step 1: Run full test suite**

Run: `docker compose exec app bundle exec rspec`

Expected: all green. Fix anything broken (factories that referenced `last_heartbeat_at`, request specs that depended on old notification timing, etc.) before proceeding.

- [ ] **Step 2: Run rubocop on touched files**

Run: `docker compose exec app bundle exec rubocop app/services/processes/execute_service.rb app/services/job_runs/execute_service.rb app/services/job_runs/cancel_service.rb app/services/hooks/execute_service.rb app/services/rsync/execute_service.rb app/services/jobs/terminate_stuck_jobs_service.rb app/jobs/job_runs/cancel_job.rb app/jobs/jobs/execute_job.rb app/jobs/scheduler_job.rb app/models/job_run.rb app/models/concerns/job_runs/state_machine.rb`

Expected: no offenses. Fix any.

- [ ] **Step 3: Verify project tracking**

Mark the relevant entry in `docs/PROJECT.md` complete (per CLAUDE.md). Read the file and locate the matching task; if not present, add an entry under the appropriate section.

- [ ] **Step 4: Final commit**

Only commit if step 1–3 produced changes:

```bash
git add -p   # review carefully
git commit -m "Fix style and update project tracking after executor redesign"
```

---

## Open questions / call-outs for the implementer

1. **Immediate vs deferred terminal transition (Task 9):** the plan defers terminal transition until after post-hook to keep "exactly one terminal transition" invariant. The user's brainstorming outline suggested immediate transition after each phase. If they push back, the alternative is to make `mark_failed` accept `running → failed AND failed → failed` and guard each call with `if job_run.running?`. Confirm before deviating.
2. **`jobs.stuck_threshold` rename (Task 11):** kept the name to avoid migrating existing user config. If you want a clearer name (`jobs.reaper_grace_seconds`), do it in a follow-up with a config migration.
3. **Worker queue routing (Task 12 Step 4):** if `config/queue.yml` doesn't already process the `workers` queue, ask the user how they want it routed.
4. **Cancel during success/failure hook:** the design does *not* allow canceling the success/failure hook — once the terminal state is set, cancellation no longer has any effect. The cancel job will skip (terminal state check), and any in-flight hook will run to completion. If this is unacceptable, add a checkpoint *before* `run_outcome_hook` and treat a late cancel as "terminal state stands, but the outcome hook is skipped" — not a clean state machine, so flag for discussion.
5. **PID recycling:** `Processes::ExecuteService#call` clears `pid` to nil in `ensure`. That closes the recycling window for cancellation; the reaper handles nil-pid rows via the grace window. If the implementer changes the pid lifecycle, both code paths need re-evaluating.

---

**Plan complete.** Estimated effort: ~6–8 hours for an engineer familiar with the codebase, longer if unfamiliar. TDD discipline throughout — every production-code step has a failing test preceding it.
