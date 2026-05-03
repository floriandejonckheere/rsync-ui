# Feature Name

<!-- One paragraph: what problem this feature solves and why it belongs in the application. -->

## Assumptions & non-goals

<!-- List what this design takes for granted (e.g. "users are already authenticated") and what it explicitly does NOT cover (e.g. "bulk import is out of scope"). Resolving ambiguities here prevents re-discovery during implementation. -->

- Assumption: ...
- Non-goal: ...

## Configuration

Configuration keys:
- [ ] `namespace.feature_name` (type: boolean, category: features, default: false)

## Database model

### `model_name` table

Columns:
- [ ] Column name (type) — purpose
- [ ] Column name (type, encrypted) — purpose if it contains sensitive data
- [ ] `enabled` (boolean, default: true)
- [ ] `user` (foreign key, UUID)

Enum columns:
- [ ] `status`: pending, active, inactive

Associations:
- [ ] `ModelA` has many `ModelB` (through `join_table`)
- [ ] Join table attributes: column_a, column_b

Create the following files:
- [ ] `db/migrate/20220101000000_create_model_name.rb` — migration
- [ ] `app/models/model_name.rb` — model definition
- [ ] `spec/models/model_spec.rb` — validations, associations, scopes

- [ ] `spec/factories/models.rb` — factory definition

## Authorization

Policy actions:
- [ ] `index?` — any authenticated user
- [ ] `show?` — record owner or admin
- [ ] `create?` — any authenticated user
- [ ] `update?` — record owner or admin
- [ ] `destroy?` — record owner or admin

Create the following files:
- [ ] `app/policies/model_policy.rb` — all policy actions, relation scope
- [ ] `spec/policies/model_policy_spec.rb` — policy spec

## Controller actions

Actions:
- [ ] `index`
- [ ] `show`
- [ ] `new`
- [ ] `create`
- [ ] `edit`
- [ ] `update`
- [ ] `destroy`

Create the following files:
- [ ] `app/controllers/models_controller.rb` — all actions
- [ ] `spec/requests/models_request_spec.rb` — CRUD, authentication, authorization

Notes:
- [ ] Return HTTP 404 if feature is disabled

## User interface

Views:
- [ ] Sidebar item (`/models`)

- [ ] Index page (`/models`)
  - [ ] Table with columns: name, status, created at, actions
  - [ ] Search by name and description
  - [ ] Empty state when no records exist
  - [ ] "New" button in the actions bar

- [ ] New / Edit form (`/models/new`, `/models/:id/edit`)
  - [ ] Field: name (required)
  - [ ] Field: description (optional)
  - [ ] Field: enabled toggle

- [ ] Show page (`/models/:id`)
  - [ ] Display all attributes
  - [ ] Inline action: ...

- [ ] Destroy action
  - [ ] Confirmation dialog before delete

Notes:
- [ ] Don't add sidebar item if feature is disabled

## Services

Services:
- [ ] `Models::CreateService` — wraps model creation and triggers side effects
- [ ] `Models::NotifyJob` — background job triggered on create/update

Email templates:
- [ ] `model_created`: name, created at, triggered by

Create the following files:
- [ ] `app/services/models/create_service.rb` — service logic
- [ ] `spec/services/models/create_service_spec.rb` — happy path, error path

## Seeds

- [ ] `db/seeds/development/08_models.rb` — seeding code
- [ ] `db/seeds/development/08_models.csv` — seed data

- [ ] `app/services/models/import_service.rb` — import service
- [ ] `spec/services/models/import_service_spec.rb` — import service test

- [ ] `app/services/models/export_service.rb` — export service
- [ ] `spec/services/models/export_service_spec.rb` — export service test

## Implementation order

1. Migration + model + factory + specs
2. Route + controller + policy + specs
3. Views
4. Services + jobs + specs
5. Background job(s) + job spec(s) (if any)
6. Mailer + email templates (if any)
7. Seeds (if any)

## Open questions

- [ ] Question 1?
- [ ] Question 2?
