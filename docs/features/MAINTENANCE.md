# Maintenance

Allow the (admin) user to run routine maintenance tasks.

## Database table & model

### `tasks` table

Columns:
- [x] `name`: string
- [x] `class_name`: string
- [x] `last_run_at`: datetime, nullable
- [x] `last_run_by`: uuid, nullable, foreign key to `users`
- [x] `status`: string, nullable
- [x] `configuration`: string, nullable
- [x] `error_class`: string, nullable
- [x] `error_message`: text, nullable

Enum columns:
- [x] `status`: running, completed, failed

Associations:
- [x] `Task` belongs to `User` (`last_run_by`)

Create the following files:
- [x] `db/migrate/20260523132833_create_tasks.rb` — migration
- [x] `app/models/task.rb` — model definition
- [x] `spec/models/task_spec.rb` — validations, associations, scopes

- [x] `spec/factories/tasks.rb` — factory definition

## Controller actions

### `TasksController` file

Actions:
- [x] `index`: list all tasks (rendered inline on the Configuration page via `ConfigurationsController#index`, not a dedicated `tasks#index` action)
- [x] `run`: run a task

Create the following files:
- [x] `app/controllers/tasks_controller.rb` — `run` action only
- [x] `spec/requests/tasks_request_spec.rb` — CRUD, authentication, authorization

## Authorization

### `TaskPolicy`

Policy actions:
- [x] `run?` — admin

Create the following files:
- [x] `app/policies/task_policy.rb` — all policy actions, relation scope
- [x] `spec/policies/task_policy_spec.rb` — policy spec

## User interface

Views:
- [x] In the Configuration page, add a "Maintenance" card that expands to the list of tasks
- [x] Mimick the interface of the configuration toggles
  - [x] Name and description (add i18n translations) on the left
  - [x] Run button on the right
  - [x] Depends on: `configuration` (if any)
  - [x] Disable entire row when the relevant configuration is disabled

When the user clicks the run button, it is disabled and replaced with a spinner (like the test connection button).
A synchronous POST request is sent to the `run` action of the task.
No arguments are required.
When the request is completed, a green checkbox should appear on the left of the button and the button should be enabled again.
If the request fails, a red cross should appear and the error message should be displayed in a tooltip.

## Services & business logic

Services:
- [x] `Tasks::ExecuteService` — Execute the task by constantizing the class name and calling the `call` method

- Create the following files:
- [x] `app/services/tasks/execute_service.rb` — service logic
- [x] `spec/services/tasks/execute_service_spec.rb` — happy path, error path

## Seeds

- [x] `db/seeds/02_tasks.rb` — seeding code (delegates to `Tasks::ImportService`)
- [x] `db/seeds/02_tasks.csv` — seed data (missing a repository disk-size task — see below)

## Tasks

### Sync SSH config

Name: `sync_ssh_config`
Description: Sync the SSH config file with the database
Class: `Servers::SyncSSHConfigTask` (implemented; class name differs from the `Tasks::SSHConfigService` name originally planned below)

The class should call `Servers::SyncSSHConfigService.call`.

Implemented, but not planned above — seeded in `db/seeds/02_tasks.csv`:
- [x] `execute_jobs` — `Jobs::ExecuteTask`, depends on `scheduler`
- [x] `terminate_stuck_job_runs` — `JobRuns::TerminateStuckTask`, depends on `scheduler`
- [x] `check_connectivity` — `Servers::CheckConnectivityTask`, depends on `connectivity`
- [x] `measure_resource_usage` — `Servers::MeasureResourceUsageTask`, depends on `resource_usage`

Missing:
- [ ] A repository disk-size measurement task (e.g. `measure_disk_size` / `Repositories::MeasureDiskSizeTask`, depends on `disk_size`) is not seeded in `db/seeds/02_tasks.csv`. Disk size is currently only measured automatically by `SchedulerJob#schedule_disk_size` (`app/jobs/scheduler_job.rb`) and after a job run completes — there is no way for a user to trigger it manually from the Maintenance card.

## Implementation order

1. Migration + model + factory + specs
2. Route + controller + policy + specs
3. Views
4. Services + jobs + specs
5. Background job(s) + job spec(s) (if any)
6. Mailer + email templates (if any)
7. Seeds (if any)
