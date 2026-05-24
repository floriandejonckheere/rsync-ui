# JobRun State Machine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `JobRun`'s raw `enum :status` and scattered `update!(status: ...)` calls with a `state_machines-activerecord` state machine that owns all status transitions and fires ActionCable / Turbo Stream side effects via a dedicated `JobRuns::BroadcastService`.

**Architecture:** The state machine lives in a `JobRuns::StateMachine` concern (`app/models/concerns/job_runs/state_machine.rb`) included by `JobRun`, keeping the model file thin. Events accept keyword arguments — `progress!(bytes_copied:, progress:)` and `error!(error_class: nil, error_messages: nil)` — which `before_transition` callbacks read from `transition.args.first` and assign to the record before saving. `after_transition` callbacks call `JobRuns::BroadcastService` class methods. `ExecuteService` calls events directly with no pre-assignment and contains no broadcast code.

**Tech Stack:** `state_machines-activerecord` gem, existing ActionCable channels, `Turbo::StreamsChannel`

---

### Task 1: Add the gem

**Files:**
- Modify: `Gemfile`

- [ ] **Step 1: Add the gem**

In `Gemfile`, after the existing gems block, add:

```ruby
gem "state_machines-activerecord"
```

- [ ] **Step 2: Install**

```bash
docker compose exec app bundle install
```

Expected: bundle resolves and installs `state_machines-activerecord` and its dependency `state_machines`.

- [ ] **Step 3: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "Add state_machines-activerecord gem"
```

---

### Task 2: Create `JobRuns::BroadcastService`

Extracts all ActionCable and Turbo Stream broadcast logic from `JobRuns::ExecuteService` into one place. Nothing in this task changes existing behaviour — the service is new and untested code gets the tests first.

**Files:**
- Create: `app/services/job_runs/broadcast_service.rb`
- Create: `spec/services/job_runs/broadcast_service_spec.rb`

- [ ] **Step 1: Write the failing tests**

Create `spec/services/job_runs/broadcast_service_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe JobRuns::BroadcastService do
  let(:user) { create(:user) }
  let(:job) { create(:job, user:) }

  before do
    allow(ActionCable.server).to receive(:broadcast)
    allow(Turbo::StreamsChannel).to receive(:broadcast_remove_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
  end

  describe ".broadcast_started" do
    let(:job_run) { create(:job_run, :running, job:, user:) }

    it "broadcasts the started event to the job run status channel" do
      described_class.broadcast_started(job_run)

      expect(ActionCable.server)
        .to have_received(:broadcast)
        .with(
          "job_run_status_#{job_run.id}",
          hash_including(type: "started", status: "running"),
        )
    end

    it "prepends the job run to the dashboard running list" do
      described_class.broadcast_started(job_run)

      expect(Turbo::StreamsChannel)
        .to have_received(:broadcast_prepend_to)
        .with("running_jobs_#{user.id}", hash_including(target: "running-job-runs"))
    end

    it "removes the empty state from the dashboard" do
      described_class.broadcast_started(job_run)

      expect(Turbo::StreamsChannel)
        .to have_received(:broadcast_remove_to)
        .with("running_jobs_#{user.id}", target: "running-jobs-empty")
    end
  end

  describe ".broadcast_progress" do
    let(:job_run) { create(:job_run, :running, job:, user:, progress: 42) }

    it "broadcasts the progress event to the job run status channel" do
      described_class.broadcast_progress(job_run)

      expect(ActionCable.server)
        .to have_received(:broadcast)
        .with(
          "job_run_status_#{job_run.id}",
          hash_including(type: "progress", progress: 42),
        )
    end
  end

  describe ".broadcast_complete" do
    let(:job_run) { create(:job_run, :completed, job:, user:) }

    it "broadcasts the complete event to the job run status channel" do
      described_class.broadcast_complete(job_run)

      expect(ActionCable.server)
        .to have_received(:broadcast)
        .with(
          "job_run_status_#{job_run.id}",
          hash_including(type: "complete", status: "completed"),
        )
    end

    context "when transitioning from a live state" do
      it "removes the job run from the dashboard running list" do
        described_class.broadcast_complete(job_run, from: "running")

        expect(Turbo::StreamsChannel)
          .to have_received(:broadcast_remove_to)
          .with("running_jobs_#{user.id}", target: "running_job_run_#{job_run.id}")
      end

      context "when no other jobs are running" do
        it "appends the empty state to the dashboard" do
          described_class.broadcast_complete(job_run, from: "running")

          expect(Turbo::StreamsChannel)
            .to have_received(:broadcast_append_to)
            .with("running_jobs_#{user.id}", hash_including(target: "running-job-runs"))
        end
      end

      context "when other jobs are still running" do
        before { create(:job_run, :running, user:) }

        it "does not append the empty state" do
          described_class.broadcast_complete(job_run, from: "running")

          expect(Turbo::StreamsChannel).not_to have_received(:broadcast_append_to)
        end
      end
    end

    context "when transitioning from a terminal state (hook error after completion)" do
      it "does not touch the dashboard Turbo Stream" do
        described_class.broadcast_complete(job_run, from: "completed")

        expect(Turbo::StreamsChannel).not_to have_received(:broadcast_remove_to)
        expect(Turbo::StreamsChannel).not_to have_received(:broadcast_append_to)
      end
    end
  end
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
docker compose exec app bundle exec rspec spec/services/job_runs/broadcast_service_spec.rb
```

Expected: fails with `uninitialized constant JobRuns::BroadcastService`.

- [ ] **Step 3: Implement `JobRuns::BroadcastService`**

Create `app/services/job_runs/broadcast_service.rb`:

```ruby
# frozen_string_literal: true

module JobRuns
  class BroadcastService
    LIVE_STATES = %w[pending running].freeze

    class << self
      def broadcast_started(job_run)
        ActionCable.server.broadcast(
          "job_run_status_#{job_run.id}",
          {
            type: "started",
            status: "running",
            status_text: I18n.t("job_runs.status.running"),
            started_at: job_run.started_at.iso8601,
          },
        )

        Turbo::StreamsChannel.broadcast_remove_to(
          "running_jobs_#{job_run.user_id}",
          target: "running-jobs-empty",
        )

        Turbo::StreamsChannel.broadcast_prepend_to(
          "running_jobs_#{job_run.user_id}",
          target: "running-job-runs",
          partial: "dashboard/cards/running_job_run",
          locals: { job_run: },
        )
      end

      def broadcast_progress(job_run)
        ActionCable.server.broadcast(
          "job_run_status_#{job_run.id}",
          {
            type: "progress",
            status_text: I18n.t("job_runs.status.running_progress", progress: job_run.progress),
            progress: job_run.progress,
          },
        )
      end

      def broadcast_complete(job_run, from: nil)
        helpers = ActionController::Base.helpers

        ActionCable.server.broadcast(
          "job_run_status_#{job_run.id}",
          {
            type: "complete",
            status: job_run.status,
            status_text: I18n.t("job_runs.status.#{job_run.status}"),
            started_at: job_run.started_at&.iso8601,
            completed_at: job_run.completed_at&.iso8601,
            duration: job_run.started_at ? helpers.distance_of_time_in_words(job_run.started_at, job_run.completed_at || Time.current) : nil,
          },
        )

        return unless from.nil? || LIVE_STATES.include?(from.to_s)

        Turbo::StreamsChannel.broadcast_remove_to(
          "running_jobs_#{job_run.user_id}",
          target: "running_job_run_#{job_run.id}",
        )

        return unless JobRun.where(user_id: job_run.user_id, status: LIVE_STATES).none?

        Turbo::StreamsChannel.broadcast_append_to(
          "running_jobs_#{job_run.user_id}",
          target: "running-job-runs",
          partial: "dashboard/cards/running_jobs_empty",
        )
      end
    end
  end
end
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
docker compose exec app bundle exec rspec spec/services/job_runs/broadcast_service_spec.rb
```

Expected: all examples pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/job_runs/broadcast_service.rb spec/services/job_runs/broadcast_service_spec.rb
git commit -m "Add JobRuns::BroadcastService"
```

---

### Task 3: Create `JobRuns::StateMachine` concern and include it in `JobRun`

The state machine lives in `app/models/concerns/job_runs/state_machine.rb` and is included by the model. This keeps the model file thin and the state machine definition self-contained.

Two events accept keyword arguments read via `transition.args.first`:
- `progress!(bytes_copied:, progress:)` — the `before_transition` assigns both columns so the loopback save persists them
- `error!(error_class: nil, error_messages: nil)` — the `before_transition` assigns whichever keys are present

The existing `cancel!` method on the model is removed; its timestamp logic moves into `before_transition to: :canceled`.

**Files:**
- Create: `app/models/concerns/job_runs/state_machine.rb`
- Modify: `app/models/job_run.rb`
- Modify: `spec/models/job_run_spec.rb`

- [ ] **Step 1: Write failing tests for the state machine**

Replace `spec/models/job_run_spec.rb` in full:

```ruby
# frozen_string_literal: true

RSpec.describe JobRun do
  subject(:job_run) { build(:job_run) }

  describe "associations" do
    it { is_expected.to belong_to(:job) }
    it { is_expected.to belong_to(:user) }

    it { is_expected.to have_one_attached(:output) }
    it { is_expected.to have_one_attached(:pre_hook_output) }
    it { is_expected.to have_one_attached(:post_hook_output) }
    it { is_expected.to have_one_attached(:success_hook_output) }
    it { is_expected.to have_one_attached(:failure_hook_output) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:trigger) }
    it { is_expected.to validate_presence_of(:status) }
  end

  describe "enums" do
    it "defines an enum for trigger" do
      expect(job_run)
        .to define_enum_for(:trigger)
        .with_values(manual: "manual", scheduled: "scheduled")
        .backed_by_column_of_type(:string)
    end
  end

  describe "state machine" do
    describe "initial state" do
      it "starts as pending" do
        expect(build(:job_run, status: nil)).to be_pending
      end
    end

    describe "transitions" do
      it "transitions from pending to running on start" do
        job_run = create(:job_run, :pending)

        expect { job_run.start! }
          .to change { job_run.reload.status }
          .from("pending").to("running")
      end

      it "sets started_at when starting" do
        job_run = create(:job_run, :pending)
        job_run.start!

        expect(job_run.reload.started_at).to be_present
      end

      it "transitions from running to completed on complete" do
        job_run = create(:job_run, :running)

        expect { job_run.complete! }
          .to change { job_run.reload.status }
          .from("running").to("completed")
      end

      it "sets completed_at when completing" do
        job_run = create(:job_run, :running)
        job_run.complete!

        expect(job_run.reload.completed_at).to be_present
      end

      it "transitions from running to failed on fail" do
        job_run = create(:job_run, :running)

        expect { job_run.fail! }
          .to change { job_run.reload.status }
          .from("running").to("failed")
      end

      it "transitions from pending to canceled on cancel" do
        job_run = create(:job_run, :pending)

        expect { job_run.cancel! }
          .to change { job_run.reload.status }
          .from("pending").to("canceled")
      end

      it "transitions from running to canceled on cancel" do
        job_run = create(:job_run, :running)

        expect { job_run.cancel! }
          .to change { job_run.reload.status }
          .from("running").to("canceled")
      end

      it "sets cancel_requested_at, canceled_at, and completed_at when canceling" do
        job_run = create(:job_run, :pending)
        job_run.cancel!
        job_run.reload

        expect(job_run.cancel_requested_at).to be_present
        expect(job_run.canceled_at).to be_present
        expect(job_run.completed_at).to be_present
      end

      it "does not overwrite existing cancel_requested_at when canceling" do
        cancel_requested_at = 1.minute.ago
        job_run = create(:job_run, :pending, cancel_requested_at:)
        job_run.cancel!

        expect(job_run.reload.cancel_requested_at)
          .to be_within(1.second)
          .of(cancel_requested_at)
      end

      it "transitions from any live state to errored on error" do
        %i[pending running].each do |state|
          job_run = create(:job_run, state)

          expect { job_run.error! }
            .to change { job_run.reload.status }
            .to("errored")
        end
      end

      it "accepts error_class and error_messages arguments on error" do
        job_run = create(:job_run, :running)
        job_run.error!(error_class: "RuntimeError", error_messages: "boom")
        job_run.reload

        expect(job_run.error_class).to eq "RuntimeError"
        expect(job_run.error_messages).to eq "boom"
      end

      it "performs a loopback on progress and persists bytes_copied and progress" do
        job_run = create(:job_run, :running)
        job_run.progress!(bytes_copied: 1_000, progress: 50)
        job_run.reload

        expect(job_run.status).to eq "running"
        expect(job_run.bytes_copied).to eq 1_000
        expect(job_run.progress).to eq 50
      end

      it "raises on an invalid transition" do
        job_run = create(:job_run, :completed)

        expect { job_run.complete! }
          .to raise_error(StateMachines::InvalidTransition)
      end
    end
  end

  describe "#deletable?" do
    it { expect(build(:job_run, :completed)).to be_deletable }
    it { expect(build(:job_run, :failed)).to be_deletable }
    it { expect(build(:job_run, :canceled)).to be_deletable }
    it { expect(build(:job_run, :errored)).to be_deletable }
    it { expect(build(:job_run, :pending)).not_to be_deletable }
    it { expect(build(:job_run, :running)).not_to be_deletable }
  end

  describe "#duration" do
    it "returns nil when started_at is blank" do
      job_run = build(:job_run, started_at: nil)

      expect(job_run.duration).to be_nil
    end

    it "returns elapsed seconds since started_at when running" do
      job_run = build(:job_run, :running, started_at: 5.minutes.ago, completed_at: nil)

      expect(job_run.duration).to be_within(1).of(5.minutes.to_i)
    end

    it "returns seconds from started_at to completed_at when completed" do
      job_run = build(:job_run, :completed, started_at: 10.minutes.ago, completed_at: 5.minutes.ago)

      expect(job_run.duration).to be_within(1).of(5.minutes.to_i)
    end
  end

  describe "sequence" do
    it "is assigned automatically by the database on create" do
      job_run = create(:job_run)

      expect(job_run.sequence).to be_present
    end

    it "is globally incrementing across job runs" do
      first = create(:job_run)
      second = create(:job_run)

      expect(second.sequence).to be > first.sequence
    end
  end
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
docker compose exec app bundle exec rspec spec/models/job_run_spec.rb
```

Expected: the `define_enum_for(:status)` spec passes (enum still exists), all state machine specs fail with `undefined method 'start!'`.

- [ ] **Step 3: Create the `JobRuns::StateMachine` concern**

Create `app/models/concerns/job_runs/state_machine.rb`:

```ruby
# frozen_string_literal: true

module JobRuns
  module StateMachine
    extend ActiveSupport::Concern

    included do
      state_machine :status, initial: :pending do
        state :pending
        state :running
        state :completed
        state :failed
        state :canceled
        state :errored

        event :start do
          transition pending: :running
        end

        event :progress do
          transition running: :running
        end

        event :complete do
          transition running: :completed
        end

        event :fail do
          transition running: :failed
        end

        event :cancel do
          transition %i[pending running] => :canceled
        end

        event :error do
          transition any => :errored
        end

        before_transition to: :running do |job_run|
          job_run.started_at = Time.zone.now
        end

        before_transition to: %i[completed failed canceled errored] do |job_run|
          job_run.completed_at = Time.zone.now
        end

        before_transition to: :canceled do |job_run|
          at = Time.zone.now
          job_run.cancel_requested_at ||= at
          job_run.canceled_at ||= at
        end

        before_transition on: :progress do |job_run, transition|
          kwargs = transition.args.first || {}
          job_run.bytes_copied = kwargs[:bytes_copied]
          job_run.progress = kwargs[:progress]
        end

        before_transition on: :error do |job_run, transition|
          kwargs = transition.args.first || {}
          job_run.error_class = kwargs[:error_class] if kwargs.key?(:error_class)
          job_run.error_messages = kwargs[:error_messages] if kwargs.key?(:error_messages)
        end

        after_transition on: :start do |job_run|
          next unless Configuration.get("streaming")

          JobRuns::BroadcastService.broadcast_started(job_run)
        end

        after_transition on: :progress do |job_run|
          next unless Configuration.get("streaming")

          JobRuns::BroadcastService.broadcast_progress(job_run)
        end

        after_transition on: %i[complete fail cancel error] do |job_run, transition|
          next unless Configuration.get("streaming")

          JobRuns::BroadcastService.broadcast_complete(job_run, from: transition.from)
        end
      end
    end
  end
end
```

- [ ] **Step 4: Update `app/models/job_run.rb`**

Remove `enum :status` and the `cancel!` method, add `include JobRuns::StateMachine`. The full file (above the schema comment) becomes:

```ruby
# frozen_string_literal: true

class JobRun < ApplicationRecord
  include JobRuns::StateMachine

  belongs_to :job
  belongs_to :user

  has_one_attached :output
  has_one_attached :pre_hook_output
  has_one_attached :post_hook_output
  has_one_attached :success_hook_output
  has_one_attached :failure_hook_output

  enum :trigger, {
    manual: "manual",
    scheduled: "scheduled",
  }, validate: true

  validates :trigger, presence: true
  validates :status, presence: true

  scope :by_job, ->(job_id) { where(job_id:) if job_id.present? }
  scope :by_trigger, ->(trigger) { where(trigger:) if trigger.present? }
  scope :by_status, ->(status) { where(status:) if status.present? }

  scope :started_from, ->(from) { where(started_at: from..) if from.present? }
  scope :started_to, ->(to) { where(started_at: ..to) if to.present? }

  def cancelable?
    pending? || running?
  end

  def deletable?
    completed? || failed? || canceled? || errored?
  end

  def duration
    return unless started_at

    (completed_at || Time.current) - started_at
  end
end
```

- [ ] **Step 5: Run model tests**

```bash
docker compose exec app bundle exec rspec spec/models/job_run_spec.rb
```

Expected: all examples pass.

- [ ] **Step 6: Run the cancel service spec**

```bash
docker compose exec app bundle exec rspec spec/services/jobs/cancel_service_spec.rb
```

Expected: all examples pass.

- [ ] **Step 7: Commit**

```bash
git add app/models/concerns/job_runs/state_machine.rb app/models/job_run.rb spec/models/job_run_spec.rb
git commit -m "Add JobRuns::StateMachine concern and include in JobRun"
```

---

### Task 4: Refactor `JobRuns::ExecuteService`

Replace every raw `update!(status: ...)` call with the corresponding state machine event. Events that accept arguments — `progress!` and `error!` — are called with keyword args directly; no pre-assignment is needed. Remove `broadcast_complete` and all `if Configuration.get("streaming")` broadcast guards. The log-line broadcast (`job_run_logs_*`) is not a state transition — leave it unchanged.

**Files:**
- Modify: `app/services/jobs/execute_service.rb`
- Modify: `spec/services/jobs/execute_service_spec.rb`

- [ ] **Step 1: Rewrite `JobRuns::ExecuteService`**

Replace the full file content:

```ruby
# frozen_string_literal: true

module Jobs
  class ExecuteService < ApplicationService
    STATUS_PATTERN = /^\s*([\d,]+)\s+(\d+)%\s+\S+\s+[\d:]+/

    attr_reader :job_run,
                :job,
                :trigger

    def initialize(job_run)
      super()

      @job_run = job_run
      @job = job_run.job
      @trigger = job_run.trigger
    end

    def call
      return unless job_run.pending?

      Rails.logger.info "[#{job.id}] Executing job #{job.name}"

      job_run.start!

      enqueue_notifications(job_run, "start")

      # Pre-hook: halt execution if it fails
      if Configuration.get("hooks")
        hook = job.pre_hook

        if hook&.enabled?
          result = Hooks::ExecuteService.new(hook, job_run:).call

          unless result[:success]
            job_run.error!(error_messages: "Pre-hook failed (exit #{result[:exit_status]}): #{result[:error]}")
            enqueue_notifications(job_run, "failure")

            return
          end
        end
      end

      command = Rsync::CommandService
        .new(job:)
        .call

      Tempfile.create(["job_run_#{job.name.parameterize(separator: '_')}_#{job_run.sequence}", ".log"]) do |file|
        Rails.logger.info { "[#{job.id}] Executing command: #{command}" }

        # Write full command to the log file
        file.write("#{command}\n")

        # Capture last status line
        last_status_line = nil

        result = Rsync::ExecuteService.new(command, job_run).call do |line|
          bytes_copied, progress = parse_status(line) if job.opt_progress || job.opt_progress2

          # Broadcast log line
          ActionCable.server.broadcast("job_run_logs_#{job_run.id}", { type: bytes_copied && progress ? "status" : "log", content: line }) if Configuration.get("streaming")

          if job.opt_progress2 && bytes_copied && progress
            job_run.progress!(bytes_copied:, progress:)

            last_status_line = line
          else
            file.write(line)
          end
        end

        # Write last status line to the log file
        file.write(last_status_line) if last_status_line

        file.rewind

        job_run.output.attach(
          io: file,
          filename: "job_run_#{job_run.sequence}.log",
          content_type: "text/plain",
        )

        exit_status = result.exit_status

        Rails.logger.info { "[#{job.id}] Command exited with status: #{exit_status.exitstatus || "signal #{exit_status.termsig}"}" }

        # Mark job as canceled if cancellation was requested
        if result.canceled
          job_run.cancel!
          next
        end

        # Mark job as completed or failed based on the exit status
        exit_status.success? ? job_run.complete! : job_run.fail!

        # Post-hook: always runs after rsync (success or failure)
        execute_optional_hook(job_run, "post")

        # Success/failure hooks: only run if rsync succeeded or failed
        execute_optional_hook(job_run, exit_status.success? ? "success" : "failure")

        # Send notifications
        enqueue_notifications(job_run, exit_status.success? ? "success" : "failure")
      end
    rescue StandardError => e
      job_run.error!(error_class: e.class.name, error_messages: e.message)
      enqueue_notifications(job_run, "failure")
    end

    private

    def parse_status(line)
      match = STATUS_PATTERN.match(line)
      return unless match

      [
        match[1].delete(",").to_i,
        match[2].to_i,
      ]
    end

    def enqueue_notifications(job_run, event)
      return unless Configuration.get("notifications")

      job_run.job.job_notifications.find_each do |job_notification|
        Notifications::SendJob
          .set(wait: 5.seconds)
          .perform_later(job_notification.id, job_run.id, event)
      end
    end

    def execute_optional_hook(job_run, type)
      return unless Configuration.get("hooks")

      hook = job.send(:"#{type}_hook")

      return unless hook&.enabled?

      result = Hooks::ExecuteService
        .new(hook, job_run:)
        .call

      return if result[:success]

      job_run.error!(error_messages: "#{type.capitalize}-hook failed (exit #{result[:exit_status]}): #{result[:error]}")
    end
  end
end
```

- [ ] **Step 2: Run the execute service spec**

```bash
docker compose exec app bundle exec rspec spec/services/jobs/execute_service_spec.rb
```

Expected: the non-streaming specs pass. Streaming specs may fail because `BroadcastService` calls `Turbo::StreamsChannel` which is not yet stubbed — proceed to step 3.

- [ ] **Step 3: Update streaming specs to stub `Turbo::StreamsChannel`**

In `spec/services/jobs/execute_service_spec.rb`, find the `describe "streaming"` block and add stubs for `Turbo::StreamsChannel` in its `before` block:

```ruby
describe "streaming" do
  with_configuration "streaming" => true

  let(:log_line) { "file.txt\n" }

  before do
    allow(ActionCable.server)
      .to receive(:broadcast)

    allow(Turbo::StreamsChannel).to receive(:broadcast_remove_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)

    allow(rsync_execute_service)
      .to receive(:call)
      .and_yield(log_line)
      .and_return(rsync_result)
  end

  # all existing `it` blocks remain unchanged
```

- [ ] **Step 4: Run all affected specs**

```bash
docker compose exec app bundle exec rspec spec/services/jobs/execute_service_spec.rb spec/services/jobs/cancel_service_spec.rb spec/services/job_runs/broadcast_service_spec.rb spec/models/job_run_spec.rb
```

Expected: all examples pass.

- [ ] **Step 5: Run the full test suite**

```bash
docker compose exec app bundle exec rspec
```

Expected: all examples pass.

- [ ] **Step 6: Rubocop**

```bash
docker compose exec app bundle exec rubocop app/models/job_run.rb app/models/concerns/job_runs/state_machine.rb app/services/job_runs/broadcast_service.rb app/services/jobs/execute_service.rb spec/models/job_run_spec.rb spec/services/job_runs/broadcast_service_spec.rb spec/services/jobs/execute_service_spec.rb
```

Expected: no offences. Fix any that appear.

- [ ] **Step 7: Commit**

```bash
git add app/services/jobs/execute_service.rb spec/services/jobs/execute_service_spec.rb
git commit -m "Refactor JobRuns::ExecuteService to use state machine events"
```
