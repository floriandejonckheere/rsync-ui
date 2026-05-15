# Audits

The Audits page lists all the SSH commands that have been executed on the user's server.

## Configuration

Configuration keys:
- [ ] `audits` (type: boolean, category: features, default: true)

## Database model

### `audits` table

Columns:
- [ ] `server` (foreign key, UUID)
- [ ] `user` (foreign key, UUID)
- [ ] `job` (foreign key, UUID, optional)
- [ ] `job_run` (foreign key, UUID, optional)
- [ ] `command` (text)
- [ ] `output` (text)
- [ ] `executed_at` (timestamp)
- [ ] `exit_status` (integer)
- [ ] `created_at` (timestamp)
- [ ] `updated_at` (timestamp)

Associations:
- [ ] `Audit` belongs to `Server`
- [ ] `Audit` belongs to `User`
- [ ] `Audit` belongs to `Job` (optional)
- [ ] `Audit` belongs to `JobRun` (optional)
- [ ] `Server` has many `Audit`s
- [ ] `User` has many `Audit`s
- [ ] `Job` has many `Audit`s
- [ ] `JobRun` has many `Audit`s

Create the following files:
- [ ] `db/migrate/create_audits.rb` — migration
- [ ] `app/models/audit.rb` — model definition
- [ ] `spec/models/audit_spec.rb` — validations, associations, scopes

- [ ] `spec/factories/audits.rb` — factory definition

## Controller actions

### `AuditsController` file

Actions:
- [ ] `index`
- [ ] `show`

Create the following files:
- [ ] `app/controllers/audits_controller.rb` — all actions
- [ ] `spec/requests/audits_request_spec.rb` — CRUD, authentication, authorization

Notes:
- [ ] Return HTTP 404 if feature is disabled

## Authorization

### `AuditPolicy`

Policy actions:
- [ ] `index?` — any authenticated user

Create the following files:
- [ ] `app/policies/audit_policy.rb` — all policy actions, relation scope
- [ ] `spec/policies/audit_policy_spec.rb` — policy spec

## User interface

Views:
- [ ] Sidebar item (`/audits`)

- [ ] Index page (`/audits`)
  - [ ] Table with columns: server, user, command, executed at
  - [ ] Search by name and description
  - [ ] Filter by server, user, command (text input, case-insensitive partial match), executed at (date range picker) -> see app/views/job_runs/_filters.html.erb for an example of filters
  - [ ] Empty state when no records exist

- [ ] Show page (`/audits/:id`)
  - [ ] Card with metadata: server, user, executed at, exit status
  - [ ] Card with command (code block)
  - [ ] Card with output (code block)

Notes:
- [ ] Don't add sidebar item if feature is disabled

## Services

For each call of `ssh.exec!` in a `Net::SSH.start` block, create an Audit record, capturing the following information:
- [ ] server UUID
- [ ] user UUID
- [ ] job UUID (if any)
- [ ] job run UUID (if any)
- [ ] executed at (current time)
- [ ] command
- [ ] exit status
- [ ] output

## Implementation order

1. Migration + model + factory + specs
2. Route + controller + policy + specs
3. Views
4. Services + jobs + specs
5. Background job(s) + job spec(s) (if any)
6. Mailer + email templates (if any)
