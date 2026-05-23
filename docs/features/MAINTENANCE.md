# Maintenance

Allow the (admin) user to run routine maintenance tasks.

## Database table & model

### `tasks` table

Columns:
- [ ] `name`: string
- [ ] `class_name`: string
- [ ] `last_run_at`: datetime, nullable
- [ ] `last_run_by`: uuid, nullable, foreign key to `users`
- [ ] `status`: string, nullable
- [ ] `configuration`: string, nullable
- [ ] `error_class`: string, nullable
- [ ] `error_message`: text, nullable

Enum columns:
- [ ] `status`: running, completed, failed

Associations:
- [ ] `Task` belongs to `User` (`last_run_by`)

Create the following files:
- [ ] `db/migrate/20260523132833_create_tasks.rb` — migration
- [ ] `app/models/task.rb` — model definition
- [ ] `spec/models/task_spec.rb` — validations, associations, scopes

- [ ] `spec/factories/tasks.rb` — factory definition

## Controller actions

### `TasksController` file

Actions:
- [ ] `index`: list all tasks
- [ ] `run`: run a task

Create the following files:
- [ ] `app/controllers/tasks_controller.rb` — all actions
- [ ] `spec/requests/tasks_request_spec.rb` — CRUD, authentication, authorization

## Authorization

### `TaskPolicy`

Policy actions:
- [ ] `index?` — admin
- [ ] `run?` — admin

Create the following files:
- [ ] `app/policies/task_policy.rb` — all policy actions, relation scope
- [ ] `spec/policies/task_policy_spec.rb` — policy spec

## User interface

Views:
- [ ] In the Configuration page, add a "Maintenance" card that expands to the list of tasks
- [ ] Mimick the interface of the configuration toggles
  - [ ] Name and description (add i18n translations) on the left
  - [ ] Run button on the right
  - [ ] Depends on: `configuration` (if any)
  - [ ] Disable entire row when the relevant configuration is disabled

When the user clicks the run button, it is disabled and replaced with a spinner (like the test connection button).
A synchronous POST request is sent to the `run` action of the task.
No arguments are required.
When the request is completed, a green checkbox should appear on the left of the button and the button should be enabled again.
If the request fails, a red cross should appear and the error message should be displayed in a tooltip.

## Services & business logic

Services:
- [ ] `Tasks::ExecuteService` — Execute the task by constantizing the class name and calling the `call` method

- Create the following files:
- [ ] `app/services/tasks/execute_service.rb` — service logic
- [ ] `spec/services/tasks/execute_service_spec.rb` — happy path, error path

## Seeds

- [ ] `db/seeds/02_tasks.rb` — seeding code
- [ ] `db/seeds/02_tasks.csv` — seed data

## Tasks

### Sync SSH config

Name: `sync_ssh_config`
Description: Sync the SSH config file with the database
Class: `Tasks::SSHConfigService`

The class should call `Servers::SyncSSHConfigService.call`.

## Implementation order

1. Migration + model + factory + specs
2. Route + controller + policy + specs
3. Views
4. Services + jobs + specs
5. Background job(s) + job spec(s) (if any)
6. Mailer + email templates (if any)
7. Seeds (if any)
