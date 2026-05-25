# JobService Design

**Date:** 2026-04-18
**Status:** Approved

## Overview

Implement a `JobService` that encapsulates the logic for executing a rsync `Job` inside an
`ActiveJob`. It creates and manages a `JobRun` record through its full lifecycle, executes
the rsync subprocess, captures output to an attached file, and handles failures and
unexpected errors as distinct terminal states.

## Database Changes

New migration adds three columns to `job_runs`:

| Column | Type | Nullable | Notes |
|---|---|---|---|
| `error_class` | string | yes | Ruby exception class name (e.g. `RuntimeError`) |
| `error_message` | text | yes | Exception message(s) |

The `status` enum gains a sixth value: `errored` (existing five: `pending`, `running`, `completed`, `failed`, `canceled`).

Updated enum values: `pending`, `running`, `completed`, `failed`, `errored`, `canceled`.

## Model Changes (`JobRun`)

- Add `errored` to the `status` enum.
- Extend `deletable?` to return `true` for `errored` runs (alongside `completed`, `failed`,
  `canceled`).

## `JobExecutionJob` (`app/jobs/job_execution_job.rb`)

A thin `ApplicationJob` subclass. Accepts a `Job` record and a `trigger` symbol
(`:manual` or `:scheduled`). Its only responsibility is to call `JobService`.

```
perform(job, trigger: :manual)
  JobService.new(job, trigger: trigger).call
```

Queue: `default`. No retries — the service handles state transitions explicitly and
re-queuing a failed job would create a duplicate `JobRun`.
Limit concurrency of the same job type to 1.

## `JobService` (`app/services/job_service.rb`)

### Interface

```ruby
JobService.new(job, trigger: :manual).call
```

### Execution Flow

1. **Create** a `JobRun` with `status: :pending`, `trigger:`, `user: job.user`.
2. **Transition to running** — update `status: :running`, `started_at: Time.current`.
3. **Build command** — delegate to `Rsync::CommandService.new(job).call` to get the
   argument array.
4. **Open a `Tempfile`** for combined stdout+stderr output.
5. **Spawn subprocess** with `Open3.popen2e(*command)`. Stream each chunk from the merged
   IO to the tempfile as it arrives.
6. **Wait for exit** — call `wait_thr.value` to get the `Process::Status`.
7. **Attach output** — rewind tempfile and attach to `job_run` via ActiveStorage
   (`job_run.output.attach(...)`).
8. **Set terminal status**:
   - Exit code 0 → `completed`
   - Non-zero exit code → `failed`
   - In both cases set `completed_at: Time.current`.
9. **Rescue `StandardError`** (wraps the entire flow from step 2 onwards):
   - Set `status: :errored`, `completed_at: Time.current`,
     `error_class: e.class.name`, `error_message: e.message`.
   - Still attempt to attach the tempfile if it was opened and has content.
10. **Ensure** tempfile is closed and unlinked.

### Error vs Failed distinction

| State | Cause |
|---|---|
| `failed` | rsync exited with a non-zero exit code (expected operational failure) |
| `errored` | Ruby exception raised during setup or execution (unexpected error) |
| `canceled` | Canceled by user via the UI (existing, unchanged) |

## ActiveStorage Attachment

`JobRun` gains a `has_one_attached :output` declaration. The tempfile is attached with
content type `text/plain` and a filename of `job_run_<sequence>.log`.

## Testing

- **Migration spec**: verify `errored` status and new columns exist.
- **`JobRun` model spec**: add `errored` to enum tests; extend `deletable?` tests.
- **`JobService` spec**:
  - Happy path: `JobRun` transitions through `pending → running → completed`; output attached.
  - Failure path: non-zero exit code → `failed`; output attached.
  - Error path: exception during execution → `errored`; `error_class`/`error_message` set.
- **`JobExecutionJob` spec**: delegates to `JobService`.
- Use `instance_double` for `Rsync::CommandService` and stub subprocess execution with a
  real temp command (e.g. `echo`) to avoid spawning actual rsync in tests.
