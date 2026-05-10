# Activity Log Feature Design

**Date:** 2026-04-18  
**Status:** Approved

## Objective

Implement the activity log feature: a `JobRun` model that records every execution of a sync job, with a top-level index page listing all runs in reverse chronological order, plus destroy and cancel actions.

## Assumptions & Out-of-Scope

- Log file viewing and downloading are out of scope.
- Cancel action is stubbed (`raise NotImplementedError`) — actual cancellation logic is out of scope.
- Job execution (creating `JobRun` records from running jobs) is out of scope; seeding/factory creation covers testing.
- `sequence` is per-job, not global.

## Data Model

**Table:** `job_runs`  
**Primary key:** UUID

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `job_id` | uuid FK | required |
| `user_id` | uuid FK | required (who triggered the run) |
| `sequence` | integer | auto-incremented per job via `before_create` callback |
| `trigger` | string (enum) | `manual`, `scheduled` |
| `status` | string (enum) | `pending` (default), `running`, `completed`, `failed`, `canceled` |
| `started_at` | datetime | nullable |
| `completed_at` | datetime | nullable |
| `created_at` | datetime | |
| `updated_at` | datetime | |

`duration` is derived (not stored): `completed_at - started_at` if done, `Time.current - started_at` if running, `—` otherwise.

## Authorization

`JobRunPolicy` follows the same pattern as `JobPolicy`:

- `index?` — any authenticated user
- `destroy?` — owner or admin
- `cancel?` — owner or admin
- **Relation scope** — returns user's own runs; admin sees all

## Routes

```ruby
resources :job_runs, only: [:index, :destroy] do
  member do
    patch :cancel
  end
end
```

## Controller

- `index` — authorized scope ordered by `created_at DESC`, eager-loads `job`, `job.source_repository`, `job.destination_repository`
- `destroy` — only when status is `completed`, `failed`, or `canceled`; returns 422 otherwise; redirects to `job_runs_path` on success
- `cancel` — `raise NotImplementedError`

## Views

**`index.html.erb`** — table with columns:

| Column | Notes |
|---|---|
| # | `sequence` number |
| Job | name, links to `edit_job_path` |
| Trigger | `manual` / `scheduled` badge |
| Status | colored badge (pending: gray, running: blue, completed: green, failed: red, canceled: gray) |
| Started at | formatted datetime or blank |
| Duration | completed/failed: `completed_at - started_at`; running: elapsed since `started_at`; otherwise `—` |
| Completed/failed at | formatted datetime or blank |
| Actions | Delete if `completed`/`failed`/`canceled`; Cancel if `pending`/`running` |

Empty state shown when no runs exist.

**`_job_run.html.erb`** — row partial, consistent with `_job.html.erb` pattern.

**Sidebar:** menu item added below Dashboard in `layouts/application.html.erb` using the `clock` Lucide icon.

## Testing

**`spec/factories/job_runs.rb`** — base factory plus traits: `:pending`, `:running`, `:completed`, `:failed`, `:canceled` (with appropriate `started_at`/`completed_at`).

**`spec/models/job_run_spec.rb`** — associations, validations, enum values, sequence auto-increment.

**`spec/policies/job_run_policy_spec.rb`** — `index?`, `destroy?`, `cancel?`, relation scope.

**`spec/requests/job_runs_request_spec.rb`**:
- `GET /job_runs`: authenticated → 200; unauthenticated → redirect
- `DELETE /job_runs/:id`: owner → destroys + redirects; other user → 403; non-deletable status → 422; unauthenticated → redirect
- `PATCH /job_runs/:id/cancel`: unauthenticated → redirect; other user → 403; owner → raises `NotImplementedError` (test with `expect { }.to raise_error(NotImplementedError)`)

## I18n

New keys under `job_runs:` namespace covering title, subtitle, table headers, status/trigger labels, action labels, empty state, and flash messages.
