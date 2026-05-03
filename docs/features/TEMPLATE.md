# Feature Name

<!-- One paragraph: what problem this feature solves and why it belongs in the application. -->

## Assumptions & non-goals

<!-- List what this design takes for granted (e.g. "users are already authenticated") and what it explicitly does NOT cover (e.g. "bulk import is out of scope"). Resolving ambiguities here prevents re-discovery during implementation. -->

- Assumption: ...
- Non-goal: ...

## Configuration

<!-- If this feature can be toggled via the application configuration system, describe the key(s) here. Leave this section out if the feature is always active. -->

- [ ] Add `namespace.feature_name` configuration (type: boolean, category: features, default: false)

## Database model

<!-- Describe new tables and columns, or changes to existing tables. Use checkboxes so progress can be tracked. -->

### `model_name` table

- [ ] Column name (type) — purpose
- [ ] Column name (type, encrypted) — purpose if it contains sensitive data
- [ ] `enabled` (boolean, default: true)
- [ ] `user` (foreign key, UUID)

- [ ] `app/models/model_name.rb` — model definition
- [ ] `spec/models/model_spec.rb` — validations, associations, scopes

- [ ] `spec/factories/model_factory.rb` — factory definition

<!-- Describe any enum columns. -->

- [ ] `status`: pending, active, inactive

<!-- Describe any associations. -->

- [ ] `ModelA` has many `ModelB` (through `join_table`)
- [ ] Join table attributes: column_a, column_b

## Authorization

<!-- List the policy actions required (index?, show?, create?, update?, destroy?, custom?). State who is allowed to perform each action (e.g. "owner only", "admin only", "any authenticated user"). -->

- [ ] `index?` — any authenticated user
- [ ] `show?` — record owner or admin
- [ ] `create?` — any authenticated user
- [ ] `update?` — record owner or admin
- [ ] `destroy?` — record owner or admin

- [ ] `app/policies/model_policy.rb` — all policy actions, relation scope
- [ ] `spec/policies/model_policy_spec.rb` — policy spec

## Controller actions

<!-- List the controller actions required (index, show, new, create, edit, update, destroy). -->

- [ ] `spec/requests/models_request_spec.rb` — CRUD, authentication, authorization

## User interface

<!-- Describe every page, form, and interactive element the user sees. Use nested checkboxes for sub-tasks. Note any conditional rendering (e.g. "visible only if feature flag is enabled"). -->

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

## Services

<!-- Describe any service objects, background jobs, mailers, or external integrations required. -->

- [ ] `Models::CreateService` — wraps model creation and triggers side effects
- [ ] `Models::NotifyJob` — background job triggered on create/update
- [ ] Email templates
  - [ ] `model_created`: name, created at, triggered by

- [ ] `app/services/models/create_service.rb` — service logic
- [ ] `spec/services/models/create_service_spec.rb` — happy path, error path

## Seeds

<!-- List any seed data that needs to be created or updated. -->

- [ ] `db/seeds/development/08_models.rb` — seeding code
- [ ] `db/seeds/development/08_models.csv` — seed data

- [ ] `app/services/models/import_service.rb` — import service
- [ ] `spec/services/models/import_service_spec.rb` — import service test

- [ ] `app/services/models/export_service.rb` — export service
- [ ] `spec/services/models/export_service_spec.rb` — export service test

## Implementation order

<!-- Suggest the sequence in which the pieces should be built so each layer can be tested before the next depends on it. Adjust as needed. -->

1. Migration + model + factory + specs
2. Route + controller + policy + specs
3. Views
4. Services + jobs + specs
5. Background job(s) + job spec(s) (if any)
6. Mailer + email templates (if any)
7. Seeds (if any)

## Open questions

<!-- List anything that needs a decision before or during implementation. Remove this section once all questions are resolved. -->

- [ ] Question 1?
- [ ] Question 2?
