# Log Streaming Design

**Date**: 2026-05-09
**Feature**: Real-time rsync log streaming via ActionCable

## Overview

Stream rsync process output to the browser in real time using ActionCable (Solid Cable backend). Two types of output are streamed: regular log lines (appended to the log card) and the status line (replaced each update, only when `opt_progress` or `opt_progress2` is enabled on the job).

## Architecture

Four moving parts:

1. **ActionCable connection** — authenticates the WebSocket using Devise's warden session
2. **`JobRunLogsChannel`** — authorizes subscription via `JobRunPolicy#logs?`, streams log and status messages
3. **`Jobs::ExecuteService`** — broadcasts each output line to the channel as it arrives
4. **Logs page** (`/job_runs/:id/logs`) — view + Stimulus controller that appends/replaces DOM content

## Configuration

Add to `config/configurations.yml`:
- `key: streaming`, `type: boolean`, `category: features`, `default: true`

## Routes & Controller Changes

### Rename (separate commit)
- Rename existing `logs` action → `output`: `GET /job_runs/:id/output` and update the route, policy, view, specs, and controller action
- This action redirects to the ActiveStorage blob download

### New action
- `GET /job_runs/:id/logs` — renders the live streaming page
- Returns HTTP 404 if the `streaming` feature flag is disabled
- Authorizes via existing `JobRunPolicy#logs?`

## Authorization

Duplicate the `show?` policy action in `JobRunPolicy`.

```ruby
def logs?
  user.admin? || record.user == user
end
```

The channel also enforces this policy at subscription time.

## ActionCable Connection

`app/channels/application_cable/connection.rb` — identifies the current user via `env["warden"].user`. Rejects the connection if no authenticated user is found.

## JobRunLogsChannel

`app/channels/job_run_logs_channel.rb`:

- On `subscribed`:
  1. Find `JobRun` by `params[:job_run_id]`
  2. Reject if not found or `JobRunPolicy.new(current_user, job_run).logs?` fails
  3. Reject if `Configuration.get("streaming")` is false
  4. Stream from `"job_run_logs_#{job_run_id}"`

Broadcast message format (JSON):
- `{ type: "log", content: "<line>" }` — appended to the log `<pre>`
- `{ type: "status", content: "<line>" }` — replaces the status line element

## Jobs::ExecuteService Changes

Inside the block yielded to `Rsync::ExecuteService#call`, add broadcasts alongside each existing write path:

- **Regular log lines**: broadcast `{ type: "log", content: line }` before writing to the temp file
- **Status lines** (when `opt_progress` or `opt_progress2` is enabled and line matches `STATUS_PATTERN`): broadcast `{ type: "status", content: line }`

Broadcasting is skipped entirely when `Configuration.get("streaming")` is false.

Broadcast call: `ActionCable.server.broadcast("job_run_logs_#{job_run.id}", { type:, content: line })`

## Frontend

### Logs page (`app/views/job_runs/logs.html.erb`)

Two cards:

1. **Info card** (full-width flexbox): job name, status badge, started at, completed at
2. **Log card** (mimics output card from show page):
   - `<pre>` element for log lines
   - Status line element at the bottom (only rendered when `job.opt_progress || job.opt_progress2`)
   - `data-controller="job-run-logs"` with `data-job-run-logs-job-run-id-value="<id>"`

### `job_run_logs_controller.js` (Stimulus)

- `connect()` — subscribes to `JobRunLogsChannel` with the job run ID
- Handles `log` messages: appends content to the `<pre>` element
- Handles `status` messages: replaces content of the status line element (no-op if the element is absent — i.e. neither `opt_progress` nor `opt_progress2` is enabled)
- `disconnect()` — unsubscribes from the channel

## Testing

- **`spec/channels/job_run_logs_channel_spec.rb`**: subscription success for authorized user; rejection for unauthorized user, missing job run, and disabled feature flag
- **`spec/requests/job_runs_request_spec.rb`**: `logs` action returns 200 for authorized user, 404 when feature disabled; `output` action returns redirect
- **`spec/services/jobs/execute_service_spec.rb`**: `ActionCable.server.broadcast` called with correct message types when streaming enabled; not called when disabled

## Commit Plan

1. Rename `logs` → `output` (route, controller action, policy, views, specs)
2. Add `streaming` configuration key
3. Add `ApplicationCable::Connection`
4. Add `JobRunLogsChannel`
5. Add broadcasting to `Jobs::ExecuteService`
6. Add logs controller action and view
7. Add Stimulus controller
8. Add specs
