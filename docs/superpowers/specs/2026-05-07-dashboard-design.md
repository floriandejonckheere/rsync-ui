# Dashboard Feature Design

**Date:** 2026-05-07
**Status:** Approved

## Overview

Extend the existing dashboard with three rows of summary cards providing a comprehensive overview of synchronization jobs, repositories, storage, and server health. The third row (server health) already exists; this spec covers rows one and two plus the Chart.js pie chart component.

## Layout

The dashboard view is restructured into three rows:

- **Row 1** — 4-column CSS grid (`grid grid-cols-4 gap-4`)
  - Status card: `col-span-2` (double width)
  - Last job run card: `col-span-1`
  - Next scheduled job card: `col-span-1`
- **Row 2** — same 4-column grid
  - Repositories card: `col-span-1`
  - Storage card: `col-span-1`
  - Remaining 2 columns: empty
- **Row 3** — existing server health section, unchanged (`flex flex-wrap gap-4`)

## Data Loading (Controller)

`DashboardController#index` is extended with the following instance variables. No new models or migrations are required.

| Variable | Query |
|---|---|
| `@job_run_stats` | `current_user.job_runs` scoped to the past 24h, grouped by status (hash of status → count) |
| `@health_status` | Derived from `@job_run_stats`: `:unknown` if empty, `:degraded` if any `failed` or `errored` runs exist, `:healthy` otherwise. `canceled` does not count as degraded (it is intentional). |
| `@last_job_run` | `current_user.job_runs.includes(:job).order(started_at: :desc).first` |
| `@next_job` | `current_user.jobs.where(enabled: true).where.not(schedule: nil)` loaded into Ruby, then `min_by(&:scheduled_next_run)` to find the soonest upcoming run. The view calls `@next_job.scheduled_next_run` to display the time. |
| `@repository_counts` | `current_user.repositories.group(:repository_type).count` → `{"local" => N, "remote" => N}` |
| `@storage_used` | `ResourceUsage.where(server: current_user.servers).sum(:disk_used)` |
| `@storage_total` | `ResourceUsage.where(server: current_user.servers).sum(:disk_total)` |
| `@servers` | Existing query, unchanged |

## Components (ERB Partials)

### `cards/_status.html.erb`
- Health label with colored badge: green (Healthy), amber (Degraded), gray (Unknown)
- Chart.js Doughnut chart via `pie_chart` Stimulus controller
- Custom HTML legend below canvas: status name + count per slice
- Zero-data fallback: single gray slice

### `cards/_last_job_run.html.erb`
- Displays: job name, started at, duration, ended at, status badge
- Empty state if `@last_job_run` is nil: clock icon + "No runs yet"

### `cards/_next_job.html.erb`
- Displays: job name, next scheduled run time (formatted as datetime + relative time)
- Empty state if `@next_job` is nil: calendar icon + "No scheduled jobs"

### `cards/_repositories.html.erb`
- Two count displays side by side: Local (N) and Remote (N)
- Always renders; counts default to 0

### `cards/_storage.html.erb`
- Reuses existing `_gauge.html.erb` partial
- Percent: `disk_used / disk_total * 100` (clamped 0–100)
- Detail: "X of Y" using `number_to_human_size`
- Fallback: renders gauge with nil percent (shows `—`) when no data

## Pie Chart (Stimulus Controller)

**File:** `app/javascript/controllers/pie_chart_controller.js`

- Uses Chart.js `doughnut` type
- Data passed via `data-pie-chart-slices-value` (JSON object: `{"completed":12,"failed":2,...}`)
- Color mapping:
  - `completed` → green (`#22c55e`)
  - `failed` → red (`#ef4444`)
  - `errored` → dark red (`#b91c1c`)
  - `canceled` → gray (`#9ca3af`)
  - `pending` → blue (`#3b82f6`)
  - `running` → light blue (`#93c5fd`)
- Chart.js legend disabled; custom HTML legend rendered in ERB below canvas
- Registered in `app/javascript/controllers/index.js` via existing auto-import

**Dependency:** `chart.js` added via `yarn add chart.js`

## Edge Cases

| Scenario | Behavior |
|---|---|
| No job runs in past 24h | Status = Unknown, pie chart shows single gray circle |
| No runs ever | Last job run card shows "No runs yet" empty state |
| No enabled scheduled jobs | Next job card shows "No scheduled jobs" empty state |
| No resource usage data | Storage gauge shows `—` in center |
| No repositories | Repository counts show 0 / 0 |

## Out of Scope

- Migrating existing gauge Stimulus controller to Chart.js (separate task)
- Real-time updates via ActionCable (future visualization feature)
- Auto-refresh via Turbo Frames

## Files Changed

- `app/controllers/dashboard_controller.rb` — extend `index` action
- `app/views/dashboard/index.html.erb` — restructure layout into rows
- `app/views/dashboard/cards/_status.html.erb` — new
- `app/views/dashboard/cards/_last_job_run.html.erb` — new
- `app/views/dashboard/cards/_next_job.html.erb` — new
- `app/views/dashboard/cards/_repositories.html.erb` — new
- `app/views/dashboard/cards/_storage.html.erb` — new
- `app/javascript/controllers/pie_chart_controller.js` — new
- `config/locales/dashboard/en.yml` — add new strings
- `package.json` / `yarn.lock` — add `chart.js`
