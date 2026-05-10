# Job Trigger Endpoint Design

**Date:** 2026-04-18
**Status:** Approved

## Overview

Add a `POST /job_runs` endpoint that manually enqueues a `JobExecutionJob` for a given
`Job`, and expose a "Run" button on each row of the jobs list. Disabled jobs render the
button in a non-interactive state.

## Route

Add `:create` to the existing `resources :job_runs`:

```ruby
resources :job_runs, only: [:index, :create, :destroy] do
  member do
    patch :cancel
  end
end
```

## Controller — `JobRunsController#create`

1. Find the `Job` by `params[:job_id]`.
2. Authorize with `authorize! JobRun.new(job: @job)` (delegates to `JobRunPolicy#create?`).
3. Guard: if `@job.disabled?`, respond with `head :unprocessable_content` (HTTP 422).
4. Enqueue `JobExecutionJob.perform_later(@job, trigger: "manual")`.
5. Redirect to `job_runs_path` with flash notice `t(".success")`.

## Policy — `JobRunPolicy#create?`

```ruby
def create?
  user.admin? || record.job.user == user
end
```

Mirrors the ownership rule already on `destroy?` and `cancel?`.

## View — `app/views/jobs/_job.html.erb`

Add a `button_to` in the actions cell, between the existing edit and delete buttons:

- **Enabled job**: standard `btn-icon-outline btn-icon-md` styling, play icon
  (`lucide "play"`), posts to `job_runs_path(job_id: job.id)`.
- **Disabled job**: same button with `disabled: true`, `cursor-not-allowed` added to the
  class, and muted text colour (`text-gray-400 dark:text-gray-600`) instead of the default
  interactive colour. The form is still rendered; the browser enforces non-submission.

## I18n

New keys required (both `en` and any other locales in `config/locales/`):

```yaml
jobs:
  actions:
    run: "Run job"

job_runs:
  create:
    success: "Job queued successfully"
```

## Testing

- **`JobRunPolicy` spec**: add `create?` tests for owner, admin, and other-user cases.
- **`JobRunsController` request spec**: POST to `job_runs_path` enqueues
  `JobExecutionJob`; returns redirect for authorized user; returns 403 for unauthorized
  user; returns 422 when job is disabled.
- **View**: covered implicitly by request spec; no separate system spec needed.
