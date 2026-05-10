# Hooks

A file synchronization job sometimes needs to preparatory work before it starts, or finishing work after it's done.
For example, shutting down a database system or syncing disk I/O.
This feature allows you to define hooks that will be executed before or after a job.
The hook can be passed arguments based on the job.

Types of hooks:

- **Pre-hook**: executed before the job starts
- **Post-hook**: executed after the job finishes (regardless of success or failure)
- **Success hook**: executed if the job succeeds
- **Failure hook**: executed if the job fails

Common arguments:

- **Job ID**: `{job_id}`, the ID of the executing job
- **Job name**: `{job_name}`, the name of the executing job
- **Trigger**: `{trigger}`, the trigger that started the job run (e.g. "manual", "scheduled")
- **Job sequence**: `{job_sequence}`, the sequence number of the executing job
- **Source ID**: `{source_id}`, the ID of the source repository
- **Source name**: `{source_name}`, the name of the source repository
- **Destination ID**: `{destination_id}`, the ID of the destination repository 
- **Destination name**: `{destination_name}`, the name of the destination repository
- **Started at**: `{started_at}`, the time the job started
- **User ID**: `{user_id}`, the ID of the user who started the job
- **User name**: `{user_name}`, the name of the user who started the job

Post-, success, and failure hook arguments:

- **Finished at**: `{finished_at}`, the time the job finished
- **Duration**: `{duration}`, the duration of the job in seconds
- **Status**: `{status}`, the status of the job (e.g. "completed", "failed", "errored")
- **Error**: `{error}`, the error message if the job failed

## Assumptions & non-goals

- Assumption: the hook is a single command-line, with or without arguments. Any more advanced logic is out of scope, and can just be put in a script by the user.
- Out of scope: running as a different user.
- Out of scope: running on a remote server.

## Configuration

- [ ] Add `hooks` configuration (type: boolean, category: features, default: false)

## Database model

<!-- Describe new tables and columns, or changes to existing tables. Use checkboxes so progress can be tracked. -->

### `hooks` table

- [ ] `id` (primary key)
- [ ] `name` (string)
- [ ] `hook_type` (string, enum): pre, post, success, failure
- [ ] `command` (string)
- [ ] `arguments` (string)
- [ ] `enabled` (boolean)
- [ ] `created_at` (datetime)
- [ ] `updated_at` (datetime)

Associations:
- [ ] `Hook` belongs to `Job`

Create the following files:
- [ ] `db/migrate/20220101000000_create_hooks.rb` — migration
- [ ] `app/models/hook.rb` — model definition
- [ ] `spec/models/hook_spec.rb` — validations, associations, scopes

- [ ] `spec/factories/hooks.rb` — factory definition

### `jobs` table

Columns:
- [ ] `pre_hook_id` (UUID)
- [ ] `post_hook_id` (UUID)
- [ ] `success_hook_id` (UUID)
- [ ] `failure_hook_id` (UUID)

Associations:
- [ ] `Job` has one `Hook` (pre_hook)
- [ ] `Job` has one `Hook` (post_hook)
- [ ] `Job` has one `Hook` (success_hook)
- [ ] `Job` has one `Hook` (failure_hook)

Create the following files:
- [ ] `db/migrate/20220101000000_add_hooks_to_jobs.rb` — migration

Update the following files:
- [ ] `app/models/job.rb` — associations

### `job_runs` table

Associations:
- [ ] `JobRun` has one attached `pre_hook_output`
- [ ] `JobRun` has one attached `post_hook_output`
- [ ] `JobRun` has one attached `success_hook_output`
- [ ] `JobRun` has one attached `failure_hook_output`

## Authorization

Policy actions:
- [ ] `update?` — record owner or admin
- [ ] `destroy?` — record owner or admin

Create the following files:
- [ ] `app/policies/hook_policy.rb` — all policy actions, relation scope
- [ ] `spec/policies/hook_policy_spec.rb` — policy spec

## Controller actions

Let the jobs model and controller accept nested attributes for all four hooks.
Update the controller and specs.

Notes:
- [ ] Only if feature is enabled

## User interface

Views:
- [ ] Edit jobs page: add a card below custom options: "Hooks"
  - [ ] Section for each hook type: "Pre-hook", "Post-hook", "Success hook", "Failure hook"
  - [ ] Input field for command
  - [ ] Input field for arguments
  - [ ] Checkbox for enabling/disabling hook
  - [ ] Mimick the existing "Notifications card"
  - [ ] At the bottom, a short information message about the hook arguments, and which variables can be used in the command (see above)

Notes:
- [ ] Don't show card if feature is disabled

Views:
- [ ] Job run logs page
  - [ ] Add a card for each enabled and configured hook
  - [ ] Show the command and arguments
  - [ ] Show the output of the hook

## Services

Services:
- [ ] `Hooks::ExecuteService` — executes the hook command, captures the output, and saves it to the job run
- [ ] `Jobs::ExecuteService` — executes the job, calls the execute hook service for each hook
  - [ ] Only if feature is enabled
  - [ ] Only if hook is enabled
  - [ ] Pre-hook only: halt execution (transition to "errored" status) if pre-hook fails (exit code != 0) and set error message
  - [ ] If any other hooks fail, transition to "errored" status and set error message

Create the following files:
- [ ] `app/services/hooks/execute_service.rb` — service logic
- [ ] `spec/services/hooks/execute_service_spec.rb` — happy path, error path

Update the following files:
- [ ] `app/services/jobs/execute_service.rb` — call hook services
  - [ ] Describe pre-hook
    - [ ] It calls the pre-hook command
    - [ ] It captures the output
    - [ ] It saves the output to the job run
    - [ ] It halts execution if pre-hook fails (exit code != 0) and sets the status to "errored"
  - [ ] Describe post-hook
    - [ ] It calls the post-hook command
    - [ ] It captures the output
    - [ ] It saves the output to the job run
    - [ ] It does not halt execution, but sets the status to "errored" if post-hook fails (exit code != 0)
  - [ ] Describe success hook
    - [ ] It calls the success hook command
    - [ ] It captures the output
    - [ ] It does not halt execution, but sets the status to "errored" if post-hook fails (exit code != 0)
  - [ ] Describe failure hook
    - [ ] It calls the failure hook command
    - [ ] It captures the output
    - [ ] It saves the output to the job run
    - [ ] It does not halt execution, but sets the status to "errored" if post-hook fails (exit code != 0)

## Seeds

- [ ] `db/seeds/development/08_hooks.rb` — seeding code
- [ ] `db/seeds/development/08_hooks.csv` — seed data

- [ ] `app/services/hooks/import_service.rb` — import service
- [ ] `spec/services/hooks/import_service_spec.rb` — import service test

- [ ] `app/services/hooks/export_service.rb` — export service
- [ ] `spec/services/hooks/export_service_spec.rb` — export service test

## Implementation order

1. Migration + model + factory + specs
2. Route + controller + policy + specs
3. Views
4. Services + jobs + specs
5. Background job(s) + job spec(s) (if any)
6. Mailer + email templates (if any)
7. Seeds (if any)
