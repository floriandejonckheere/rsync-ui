# Stuck Job Detection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically detect and resolve job_runs stuck in `running` or `pending` state after a worker crash, using an application-level heartbeat and periodic detection in `SchedulerJob`.

**Architecture:** A `last_heartbeat_at` timestamp on `job_runs` is updated every N seconds by the rsync execute monitor thread. `SchedulerJob` scans for stale/missing heartbeats every minute and marks stuck jobs as `errored`. Two `Configuration` keys control the interval and threshold.

**Tech Stack:** Rails 8, ActiveRecord, Solid Queue, RSpec/FactoryBot

---

## File Map

| File | Change |
|------|--------|
| `db/migrate/TIMESTAMP_add_last_heartbeat_at_to_job_runs.rb` | New migration |
| `app/models/job_run.rb` | Annotation update only (auto via annotaterb) |
| `config/configurations.yml` | Add `jobs.heartbeat_interval` and `jobs.stuck_threshold` |
| `app/services/rsync/execute_service.rb` | Write heartbeat in monitor thread |
| `app/jobs/scheduler_job.rb` | Add `detect_stuck_jobs` + `limits_concurrency` |
| `spec/services/rsync/execute_service_spec.rb` | New heartbeat test |
| `spec/jobs/scheduler_job_spec.rb` | New stuck detection tests |
| `spec/factories/job_runs.rb` | Add `last_heartbeat_at` to `:running` trait |

---

## Task 1: Migration — add `last_heartbeat_at` to `job_runs`

**Files:**
- Create: `db/migrate/TIMESTAMP_add_last_heartbeat_at_to_job_runs.rb`

- [ ] **Step 1: Generate the migration**

```bash
docker compose exec app rails generate migration AddLastHeartbeatAtToJobRuns last_heartbeat_at:datetime:index
```

- [ ] **Step 2: Verify the generated migration body matches this**

Open the generated file and confirm it contains:

```ruby
# frozen_string_literal: true

class AddLastHeartbeatAtToJobRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :job_runs, :last_heartbeat_at, :datetime
    add_index :job_runs, :last_heartbeat_at
  end
end
```

The column is nullable (no `null: false`) — null means the job hasn't written its first heartbeat yet.

- [ ] **Step 3: Run the migration**

```bash
docker compose exec app rails db:migrate
```

Expected: migration runs without error, `db/schema.rb` gains `t.datetime "last_heartbeat_at"` and a corresponding index under `job_runs`.

- [ ] **Step 4: Update model annotations**

```bash
docker compose exec app bundle exec annotaterb models
```

- [ ] **Step 5: Commit**

```bash
git add db/migrate/ db/schema.rb app/models/job_run.rb
git commit -m "Add last_heartbeat_at to job_runs"
```

---

## Task 2: Configuration keys

**Files:**
- Modify: `config/configurations.yml`

- [ ] **Step 1: Append the two new keys to `config/configurations.yml`**

Add at the end of the file:

```yaml
- key: jobs.heartbeat_interval
  type: integer
  category: jobs
  default: 30
- key: jobs.stuck_threshold
  type: integer
  category: jobs
  default: 300
```

No dependencies — stuck detection is always active.

- [ ] **Step 2: Verify the keys load correctly**

```bash
docker compose exec app rails runner "puts Configuration.get('jobs.heartbeat_interval'); puts Configuration.get('jobs.stuck_threshold')"
```

Expected output:
```
30
300
```

- [ ] **Step 3: Commit**

```bash
git add config/configurations.yml
git commit -m "Add jobs.heartbeat_interval and jobs.stuck_threshold configuration keys"
```

---

## Task 3: Heartbeat writing in `Rsync::ExecuteService`

**Files:**
- Modify: `app/services/rsync/execute_service.rb`
- Modify: `spec/services/rsync/execute_service_spec.rb`

- [ ] **Step 1: Write the failing test**

Add to `spec/services/rsync/execute_service_spec.rb` inside `describe "#call"`:

```ruby
it "writes a heartbeat to job_run while running" do
  service.call

  expect(job_run.reload.last_heartbeat_at).to be_present
end
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
docker compose exec app bundle exec rspec spec/services/rsync/execute_service_spec.rb --format documentation
```

Expected: the new example fails with `expected nil to be present`.

- [ ] **Step 3: Implement heartbeat writing in the monitor thread**

Replace the entire `call` method in `app/services/rsync/execute_service.rb`:

```ruby
def call(&block)
  exit_status = nil
  canceled = false

  Open3.popen2e(command, pgroup: true) do |_stdin, output, wait_thr|
    job_run.update!(pid: wait_thr.pid)

    buffer = +""
    cancel_sent = false
    mutex = Mutex.new
    condition_variable = ConditionVariable.new
    stop_monitor = false
    last_heartbeat_at = nil
    heartbeat_interval = Configuration.get("jobs.heartbeat_interval").to_i

    monitor = Thread.new do
      loop do
        mutex.synchronize { condition_variable.wait(mutex, CANCEL_MONITOR_INTERVAL) }

        now = Time.zone.now
        if last_heartbeat_at.nil? || (now - last_heartbeat_at) >= heartbeat_interval
          job_run.update!(last_heartbeat_at: now)
          last_heartbeat_at = now
        end

        break if stop_monitor
        next if cancel_sent
        next if JobRun.where(id: job_run.id).pick(:cancel_requested_at).blank?

        begin
          Process.kill("TERM", -wait_thr.pid)
        rescue Errno::ESRCH
          nil
        end

        cancel_sent = true
      end
    end

    loop do
      chunk = output.readpartial(4096)

      Rails.logger.debug { chunk }

      buffer << chunk

      lines = buffer.split(/(?<=[\r\n])/)
      buffer = lines.last&.match?(/[\r\n]\z/) ? +"" : (lines.pop || +"")

      lines.each { |line| block&.call(line) }

      if !cancel_sent && JobRun.where(id: job_run.id).pick(:cancel_requested_at).present?
        begin
          Process.kill("TERM", -wait_thr.pid)
        rescue Errno::ESRCH
          nil
        end
        cancel_sent = true
      end
    rescue EOFError
      break
    ensure
      mutex.synchronize do
        stop_monitor = true
        condition_variable.signal
      end
    end

    monitor.join

    block&.call(buffer) if buffer.present?

    exit_status = wait_thr.value
    canceled = job_run.reload.cancel_requested_at?
  end

  Result.new(exit_status:, canceled:)
end
```

- [ ] **Step 4: Run the tests to confirm they all pass**

```bash
docker compose exec app bundle exec rspec spec/services/rsync/execute_service_spec.rb --format documentation
```

Expected: all examples pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/rsync/execute_service.rb spec/services/rsync/execute_service_spec.rb
git commit -m "Write heartbeat to job_run in rsync monitor thread"
```

---

## Task 4: Stuck job detection in `SchedulerJob`

**Files:**
- Modify: `app/jobs/scheduler_job.rb`
- Modify: `spec/jobs/scheduler_job_spec.rb`
- Modify: `spec/factories/job_runs.rb`

### 4a: Update the `:running` factory trait

The `:running` trait currently has no `last_heartbeat_at`. Add it so running jobs look healthy by default in tests that don't care about stuck detection:

- [ ] **Step 1: Update `spec/factories/job_runs.rb` — `:running` trait**

```ruby
trait :running do
  status { :running }
  started_at { 5.minutes.ago }
  completed_at { nil }
  last_heartbeat_at { 1.minute.ago }
end
```

- [ ] **Step 2: Run the full spec suite to confirm no regressions**

```bash
docker compose exec app bundle exec rspec spec/models/job_run_spec.rb spec/services/rsync/execute_service_spec.rb spec/jobs/scheduler_job_spec.rb --format documentation
```

Expected: all existing tests still pass.

### 4b: Write the failing tests

- [ ] **Step 3: Add stuck detection tests to `spec/jobs/scheduler_job_spec.rb`**

Add a new `describe` block after the `"resource usage scheduling"` block:

```ruby
describe "stuck job detection" do
  with_configuration "jobs.heartbeat_interval" => 30, "jobs.stuck_threshold" => 300

  context "when a running job has a stale heartbeat" do
    it "marks it as errored" do
      job_run = create(:job_run, :running, last_heartbeat_at: 10.minutes.ago)

      described_class.perform_now

      expect(job_run.reload).to be_errored
      expect(job_run.completed_at).to be_present
      expect(job_run.error_messages).to include("interrupted")
    end
  end

  context "when a running job has no heartbeat and an old started_at" do
    it "marks it as errored" do
      job_run = create(:job_run, :running, last_heartbeat_at: nil, started_at: 10.minutes.ago)

      described_class.perform_now

      expect(job_run.reload).to be_errored
    end
  end

  context "when a running job has a recent heartbeat" do
    it "leaves it running" do
      job_run = create(:job_run, :running, last_heartbeat_at: 1.minute.ago)

      described_class.perform_now

      expect(job_run.reload).to be_running
    end
  end

  context "when a running job has no heartbeat but was started recently" do
    it "leaves it running" do
      job_run = create(:job_run, :running, last_heartbeat_at: nil, started_at: 1.minute.ago)

      described_class.perform_now

      expect(job_run.reload).to be_running
    end
  end

  context "when a pending job was created long ago" do
    it "marks it as errored" do
      job_run = create(:job_run, :pending, created_at: 10.minutes.ago)

      described_class.perform_now

      expect(job_run.reload).to be_errored
      expect(job_run.completed_at).to be_present
      expect(job_run.error_messages).to include("interrupted")
    end
  end

  context "when a pending job was created recently" do
    it "leaves it pending" do
      job_run = create(:job_run, :pending, created_at: 1.minute.ago)

      described_class.perform_now

      expect(job_run.reload).to be_pending
    end
  end

  context "when notifications are enabled and the job has a notification" do
    with_configuration "notifications" => true

    it "enqueues a failure notification for stuck running jobs" do
      job_run = create(:job_run, :running, last_heartbeat_at: 10.minutes.ago)
      notification = create(:notification, user: job_run.job.user)
      create(:job_notification, job: job_run.job, notification:, on_failure: true)

      described_class.perform_now

      expect(Notifications::SendJob).to have_been_enqueued
        .with(job_run.job.job_notifications.first.id, job_run.id, "failure")
    end
  end
end
```

- [ ] **Step 4: Run the tests to confirm they all fail**

```bash
docker compose exec app bundle exec rspec spec/jobs/scheduler_job_spec.rb --format documentation
```

Expected: the new `stuck job detection` examples fail with `expected running to be errored` (or similar).

### 4c: Implement `detect_stuck_jobs`

- [ ] **Step 5: Update `app/jobs/scheduler_job.rb`**

```ruby
# frozen_string_literal: true

class SchedulerJob < ApplicationJob
  limits_concurrency to: 1, key: "scheduler_job", duration: 1.minute

  def perform
    schedule_jobs
    schedule_connectivity
    schedule_resource_usage
    terminate_stuck_jobs
  end

  private

  def schedule_jobs
    return unless Configuration.get("scheduler")

    now = Time.zone.now

    Job.where(enabled: true).where.not(schedule: [nil, ""]).find_each do |job|
      cron = Fugit.parse_cron(job.schedule)
      next unless cron

      prev_tick = cron.previous_time(now).to_t
      last_scheduled_run = job.job_runs.scheduled.order(:created_at).last

      next if last_scheduled_run && last_scheduled_run.created_at >= prev_tick

      job_run = job
        .job_runs
        .create!(user: job.user, trigger: "scheduled", status: "pending")

      Jobs::ExecuteJob.perform_later(job_run)
    end
  end

  def schedule_connectivity
    return unless Configuration.get("connectivity")

    interval = Configuration.get("connectivity.interval").to_i.minutes

    Server
      .where(probed_at: [nil, ..interval.ago])
      .find_each { |server| Servers::ConnectionJob.perform_later(server) }
  end

  def schedule_resource_usage
    return unless Configuration.get("resource_usage")

    interval = Configuration.get("resource_usage.interval").to_i.minutes

    Server
      .left_joins(:resource_usage)
      .where(resource_usages: { probed_at: [nil, ..interval.ago] })
      .find_each { |server| Servers::ResourceUsageJob.perform_later(server) }
  end

  def detect_stuck_jobs
    threshold = Configuration.get("jobs.stuck_threshold").to_i.seconds.ago
    message = "Job was interrupted (no heartbeat received for over #{Configuration.get('jobs.stuck_threshold')} seconds)"

    stuck_running = JobRun.running.where(
      "last_heartbeat_at < :threshold OR (last_heartbeat_at IS NULL AND started_at < :threshold)",
      threshold:,
    )
    stuck_pending = JobRun.pending.where(created_at: ...threshold)

    (stuck_running + stuck_pending).each do |job_run|
      job_run.update!(
        status: "errored",
        completed_at: Time.zone.now,
        error_messages: message,
      )

      next unless Configuration.get("notifications")

      job_run.job.job_notifications.find_each do |job_notification|
        Notifications::SendJob
          .set(wait: 5.seconds)
          .perform_later(job_notification.id, job_run.id, "failure")
      end
    end
  end
end
```

- [ ] **Step 6: Run the stuck detection tests to confirm they pass**

```bash
docker compose exec app bundle exec rspec spec/jobs/scheduler_job_spec.rb --format documentation
```

Expected: all examples pass, including the new `stuck job detection` block.

- [ ] **Step 7: Run the full relevant test suite**

```bash
docker compose exec app bundle exec rspec spec/jobs/ spec/services/rsync/execute_service_spec.rb spec/models/job_run_spec.rb --format documentation
```

Expected: all pass.

- [ ] **Step 8: Run RuboCop on changed files**

```bash
docker compose exec app bundle exec rubocop app/jobs/scheduler_job.rb app/services/rsync/execute_service.rb
```

Expected: no offenses.

- [ ] **Step 9: Commit**

```bash
git add app/jobs/scheduler_job.rb spec/jobs/scheduler_job_spec.rb spec/factories/job_runs.rb
git commit -m "Detect and auto-resolve stuck job runs in SchedulerJob"
```
