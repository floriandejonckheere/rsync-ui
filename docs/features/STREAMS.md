# Log streaming

The user should be able to stream the rsync logs while the process is running.
The logs should be streamed in realtime using ActionCable. There are two sections that are streamed:
- [ ] The logs of the rsync process, written to the temporary output file by `Jobs::ExecuteService`
- [ ] The status line of the rsync process, parsed by `Jobs::ExecuteService` but not written to the temporary output file (it's written only at the end)

## Configuration

Configuration keys:
- [ ] `log_streaming` (type: boolean, category: features, default: true) — enable/disable feature

## Controller actions

Rename the `/job_runs/:id/logs` route to `/job_runs/:id/output`

Create a new route:
- [ ] `GET /job_runs/:id/logs`

Notes:
- [ ] Return HTTP 404 if feature is disabled

## Authorization

JobRunPolicy actions:
- [ ] `logs?` — record owner or admin

## User interface

Views:
- [ ] Logs page (`/job_runs/:id/logs`)
  - [ ] One small card (full-width) with the current job name, status (and progress), started at, completed at, flexbox across the full width
  - [ ] One card with the logs streamed from the server. Mimick the log card from the job runs show page.

## Implementation

Implement this feature.
When the process is ongoing, the logs are streamed to the client using ActionCable.
Both the logs of the rsync process (e.g. the filenames when `--verbose` is used) and the status line are streamed.
The logs are just appended to the logs card, but the status line is replaced every time it changes.
It is located at the bottom of the logs card.
