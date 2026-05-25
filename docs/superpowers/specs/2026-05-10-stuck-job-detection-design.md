# Stuck Job Detection — Design Spec

**Date:** 2026-05-10

## Problem

When a Solid Queue worker is killed mid-execution, the rsync process it spawned is also killed. The `JobRun` record stays in `running` (or `pending`) indefinitely because the `rescue StandardError` block in `JobRuns::ExecuteService` never fires — the process is dead.

Solid Queue detects dead workers via its own heartbeat/prune mechanism (every 5 min) and marks its internal job records as failed, but this does not propagate to application-level `JobRun` records.

## Solution

Application-level heartbeat on `job_runs`, with automatic resolution in `SchedulerJob`.

## Schema

Add one column to `job_runs`:

```
last_heartbeat_at :datetime, indexed
```

- Null: job has not yet written a heartbeat (still `pending` or just transitioned to `running`)
- Non-null: timestamp of the last heartbeat written by the running job

## Configuration

Two new `Configuration` keys:

| Key | Default | Description |
|-----|---------|-------------|
| `jobs.heartbeat_interval` | `30` (seconds) | How often a running job writes a heartbeat |
| `jobs.stuck_threshold` | `300` (seconds) | How long without a heartbeat before a job is considered stuck |

The 10× margin (30s interval, 5min threshold) prevents false positives for slow-but-alive jobs. Both values are configurable so users with legitimately long jobs can raise the threshold.

## Heartbeat Writing

Inside `Rsync::ExecuteService`, the existing monitor thread already loops on `CANCEL_MONITOR_INTERVAL` (5s) checking for cancellation. This thread is extended to also write heartbeats — no second thread needed.

The thread tracks elapsed time and writes `job_run.update!(last_heartbeat_at: Time.zone.now)` every `jobs.heartbeat_interval` seconds. This decouples the heartbeat rate from the cancel poll rate.

Heartbeats are only written once the job is `running`. The `pending` phase is covered separately (see below).

## Stuck Detection

`SchedulerJob` (already runs every minute via Solid Queue recurring task) gains a `detect_stuck_jobs` step:

### Stuck `running` jobs

```
status = running
AND last_heartbeat_at < stuck_threshold.ago
OR (last_heartbeat_at IS NULL AND started_at < stuck_threshold.ago)
```

The `last_heartbeat_at IS NULL` fallback handles jobs that were killed in the window between transitioning to `running` and writing their first heartbeat. `started_at` is used as the reference in that case.

### Stuck `pending` jobs

```
status = pending
AND created_at < stuck_threshold.ago
```

These were enqueued but Solid Queue lost track of them (worker killed before claiming the execution). `created_at` is the reference since `started_at` is null for pending jobs.

### Resolution

Both cases are resolved by updating the `JobRun`:

```ruby
job_run.update!(
  status: "errored",
  completed_at: Time.zone.now,
  error_message: "Job was interrupted (no heartbeat received for over #{stuck_threshold} seconds)",
)
```

Failure notifications are enqueued after resolution, consistent with how `ExecuteService` handles errors today.

## Edge Cases

- **Graceful shutdown**: worker receives SIGTERM → rsync is killed → existing cancel/rescue path runs → `JobRun` updated normally → stuck detector never fires
- **Concurrent `SchedulerJob` runs**: both instances would write the same terminal state, which is safe. A `limits_concurrency` guard will be added to `SchedulerJob` to prevent double-execution
- **Long-running jobs**: configurable threshold prevents false positives; defaults give 10× margin
- **Notifications**: stuck jobs trigger failure notifications the same as any other `errored` outcome

## Notifications

`enqueue_notifications` is a private method on `JobRuns::ExecuteService` and cannot be called from `SchedulerJob`. The stuck detection logic will inline the notification enqueueing directly (i.e. call `Notifications::SendJob.perform_later(...)` for each `job_notification` on the job), mirroring what `ExecuteService` does.

## Files Affected

- `db/migrate/` — new migration adding `last_heartbeat_at` to `job_runs`
- `app/models/job_run.rb` — model annotation update
- `app/services/rsync/execute_service.rb` — heartbeat writes in monitor thread
- `app/jobs/scheduler_job.rb` — `detect_stuck_jobs` step + `limits_concurrency`
- `config/configurations.yml` — two new integer keys: `jobs.heartbeat_interval` (default: 30) and `jobs.stuck_threshold` (default: 300), both under a `jobs` category
