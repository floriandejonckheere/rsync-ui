# Notifications — Design Spec

Date: 2026-05-01
Source: [docs/features/NOTIFICATIONS.md](../../features/NOTIFICATIONS.md)

## Goal

Allow users to configure notification destinations (Apprise URLs) and attach
them to jobs so that messages are sent on job lifecycle events (start, success,
failure).

## Architecture

A new `Notification` model stores per-user destinations (Apprise URLs,
encrypted at rest). A `JobNotification` join model links notifications to jobs
and configures which lifecycle events trigger delivery.

`JobRuns::ExecuteService` enqueues `Notifications::SendJob` for each
(notification × event) tuple at the appropriate lifecycle hook. The job
renders an event-specific ERB body via `Notifications::RenderService` and
shells out to the Apprise CLI (installed in the Docker image), which performs
the actual delivery.

A `notifications` boolean configuration (default `true`) gates the entire
feature surface — UI menu items, controllers, and the hooks in
`JobRuns::ExecuteService` all check it.

## Data model

### `notifications`

| Column        | Type     | Notes                                                  |
|---------------|----------|--------------------------------------------------------|
| `id`          | uuid     | primary key                                            |
| `user_id`     | uuid     | fk → users, not null, indexed                          |
| `name`        | string   | not null                                               |
| `description` | text     | nullable                                               |
| `url`         | text     | not null, encrypted via `encrypts :url`                |
| `enabled`     | boolean  | default `true`, not null                               |
| `created_at`  | datetime |                                                        |
| `updated_at`  | datetime |                                                        |

Validations: `name` presence; `url` presence and `URI`-parseable with a
non-blank scheme.

### `job_notifications`

| Column            | Type     | Notes                                          |
|-------------------|----------|------------------------------------------------|
| `id`              | uuid     | primary key                                    |
| `job_id`          | uuid     | fk → jobs, not null, indexed                   |
| `notification_id` | uuid     | fk → notifications, not null, indexed          |
| `enabled`         | boolean  | default `true`, not null                       |
| `on_start`        | boolean  | default `false`, not null                      |
| `on_success`      | boolean  | default `true`, not null                       |
| `on_failure`      | boolean  | default `true`, not null                       |
| `created_at`      | datetime |                                                |
| `updated_at`      | datetime |                                                |

Unique index on `(job_id, notification_id)`.

Three booleans (rather than an enum array) keep validation, querying, and
form binding straightforward.

### Associations

- `User has_many :notifications, dependent: :destroy`
- `Notification has_many :job_notifications, dependent: :destroy`
- `Notification has_many :jobs, through: :job_notifications`
- `Job has_many :job_notifications, dependent: :destroy`
- `Job has_many :notifications, through: :job_notifications`

### Configuration

New entry in `config/configurations.yml`:

```yaml
- key: notifications
  type: boolean
  category: notifications
  default: true
```

Translations in `config/locales/configurations.yml`:

## Services

### `Notifications::RenderService`

`app/services/notifications/render_service.rb`

- Args: `job_run`, `event` (`"start"` | `"success"` | `"failure"`).
- Renders ERB partial `app/views/notifications/_<event>.text.erb` with locals.
- Returns `{ title:, body:, notification_type: }` where `notification_type` is
  `"info"` / `"success"` / `"failure"` (mapped to Apprise's
  `--notification-type` flag).
- Title and field labels come from I18n
  (`config/locales/notifications.en.yml`).

Template fields per spec:
- `start`: job name, job ID, source, destination, started at, trigger,
  triggered by.
- `success`: above + completed at, duration.
- `failure`: above + error class, error message, URL to job log.

### `Notifications::SendService`

`app/services/notifications/send_service.rb`

- Args: `notification`, `job_run`, `event`.
- Calls `RenderService` to obtain title/body/type.
- Decrypts `notification.url`, then invokes Apprise:
  ```
  apprise --input-format=markdown \
          --title=<title> \
          --body=<body> \
          --notification-type=<type> \
          --config=-
  ```
  The URL is piped to stdin (one URL per line) via `--config=-` so credentials
  do not appear in `ps`/argv.
- Wraps the call in `Timeout.timeout(30)`.
- Returns `{ success:, output: }` (combined stdout/stderr). Does not raise on
  delivery failure — caller decides.

### `Notifications::TestService`

`app/services/notifications/test_service.rb`

- Args: `notification`.
- Builds a synthetic title/body (no real `JobRun` required).
- Calls Apprise the same way as `SendService` but with a 10-second timeout.
- Returns `{ success:, message: }` for the controller to surface in flash.

### `Notifications::SendJob`

`app/jobs/notifications/send_job.rb`

- Args: `job_notification_id`, `job_run_id`, `event`.
- Re-checks at run time (not enqueue time):
  - `Configuration.get("notifications")` is true,
  - `JobNotification#enabled?`,
  - `Notification#enabled?`,
  - the relevant `on_<event>` flag is true.
- Calls `SendService`. Logs failures. Relies on SolidQueue retries for
  transient errors.

### Hook into `JobRuns::ExecuteService`

A private helper:

```ruby
def enqueue_notifications(job_run, event)
  return unless Configuration.get("notifications")

  job_run.job.job_notifications.find_each do |jn|
    Notifications::SendJob.perform_later(jn.id, job_run.id, event)
  end
end
```

Called at:
- after `job_runs.create!(... status: "running" ...)` → `"start"`,
- after status update to `completed` → `"success"`,
- after status update to `failed` or `errored` → `"failure"`.

## UI

### Routes

```ruby
resources :notifications do
  member do
    post :test
  end
end
```

`JobNotification` rows are managed via nested attributes on the existing job
form — no separate controller.

### `NotificationsController`

`app/controllers/notifications_controller.rb`

- Standard `index / new / edit / create / update / destroy` + `test`.
- `before_action :authenticate_user!`.
- `before_action :ensure_notifications_enabled` → 404 unless
  `Configuration.get("notifications")`.
- `index` lists `authorized_scope(Notification)`.
- `update` masks the `url` field — blank value means "keep existing", same
  pattern as `ServersController#update_params` for `password`/`ssh_key`.
- `test` calls `Notifications::TestService.call(@notification)`, redirects
  with flash showing success or captured error.

### `NotificationPolicy`

`app/policies/notification_policy.rb`

```ruby
relation_scope { |relation| user.admin? ? relation : relation.where(user:) }

def index?   = user.present?
def show?    = user.admin? || record.user == user
def create?  = user.admin? || record.user == user
def update?  = user.admin? || record.user == user
def destroy? = update?
def test?    = update?
```

Uses the existing `User#admin?` enum (`role` column).

### Views

Mirror the `servers` layout:

- `app/views/notifications/index.html.erb`
- `app/views/notifications/_notification.html.erb`
- `app/views/notifications/_form.html.erb`
- `app/views/notifications/new.html.erb`
- `app/views/notifications/edit.html.erb`

The index page has a search button, which filters the list.
It mirrors the search button in the servers index page, and
the repositories index page. Use the Searchable concern.

The notifications form has a "Test" button that POSTs to
`notifications/:id/test`, mirroring the connection test button
in the servers form.

Notification body templates (also used as Apprise message bodies):
- `app/views/notifications/_started.text.erb`
- `app/views/notifications/_completed.text.erb`
- `app/views/notifications/_failed.text.erb`

### Job form changes

`app/views/jobs/_form.html.erb`:

- New "Notifications" card in the left column, visible only when
  `Configuration.get("notifications")` is true.
- Lists the current user's notifications. For each notification, exposes:
  `enabled`, `on_start`, `on_success`, `on_failure`.
- Backed by `accepts_nested_attributes_for :job_notifications,
  allow_destroy: true` on `Job`.
- `JobsController` strong params permit `job_notifications_attributes:
  [:id, :notification_id, :enabled, :on_start, :on_success, :on_failure,
  :_destroy]`.

Run `yarn herb:format` after changes.

### Navigation

Add a "Notifications" entry to the main menu next to "Servers" /
"Repositories", visible only when `Configuration.get("notifications")` is true.

## Docker

Both `Dockerfile` and `Dockerfile.prod` (Alpine-based):

- Add `python3 py3-pip` to `RUNTIME_DEPS`.
- Create a virtualenv at `/opt/apprise-venv` and install from
  `requirements.txt`:
  ```
  RUN python3 -m venv /opt/apprise-venv \
   && /opt/apprise-venv/bin/pip install --no-cache-dir -r requirements.txt
  ENV PATH="/opt/apprise-venv/bin:$PATH"
  ```
- Verify at build time with `apprise --version`.

A new `requirements.txt` at the repo root pins the latest Apprise release.

## Dependabot

Append to `.github/dependabot.yml`:

```yaml
  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
```

## i18n

All user-facing strings in `config/locales/notifications.en.yml`:
- model attributes,
- flash messages,
- view labels,
- notification body templates (titles and field labels).

Run `i18n-tasks normalize` after edits.

## Testing

- **Models**: `Notification` (validations, encryption, association destroy);
  `JobNotification` (validations, uniqueness, defaults).
- **Policies**: `NotificationPolicy` (owner sees own, admin sees all, other
  users blocked).
- **Services**:
  - `Notifications::RenderService` — correct title/body per event, i18n keys
    resolve.
  - `Notifications::SendService` — Apprise CLI invoked with stdin URL (stub
    `Open3.capture3`); timeout honored.
  - `Notifications::TestService` — analogous coverage.
- **Job**: `Notifications::SendJob` — no-ops when feature/notification/event
  flag disabled; calls `SendService` otherwise.
- **`JobRuns::ExecuteService`** — enqueues correct events at start / success /
  failure / errored transitions; respects `Configuration.get("notifications")`.
- **Request specs**: `NotificationsController` CRUD + `test` action; scoping
  per policy; 404 when feature disabled.
- **Job form**: nested attributes accepted; UI hidden when disabled.

## Out of scope (YAGNI)

- Rate limiting, batching, throttling.
- Per-user notification preferences beyond per-job toggles.
- Delivery history / audit log.
- Retry policy beyond SolidQueue defaults.
- Bulk import/export of notifications.

## Migration & commit plan

Per CLAUDE.md, one commit per migration and per gem/dependency:

1. Add `requirements.txt` + Dockerfile changes (Apprise install).
2. Add dependabot pip entry.
3. Migration: `CreateNotifications` (+ model, factory, specs).
4. Migration: `CreateJobNotifications` (+ model, factory, specs).
5. Add `notifications` configuration entry.
6. Add `Notification` policy + controller + views + routes + i18n.
7. Add `Notifications::RenderService` + ERB body templates.
8. Add `Notifications::SendService` + `TestService`.
9. Add `Notifications::SendJob`.
10. Hook into `JobRuns::ExecuteService`.
11. Job form integration (nested attributes, view changes).
12. Navigation menu entry.
13. Update `docs/PROJECT.md` (check off completed items).
