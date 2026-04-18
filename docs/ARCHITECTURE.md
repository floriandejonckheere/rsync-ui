# Architecture

This document describes the architectural conventions and structure of the application.

## Standard Ruby on Rails Conventions

The codebase follows standard Ruby on Rails conventions, with related code grouped by functionality: models, controllers, policies, views, etc.

```
app
├── controllers
│   ├── application_controller.rb
│   └── ...
├── errors
│   ├── application_error.rb
│   └── ...
├── helpers
│   ├── application_helper.rb
│   └── ...
├── javascript
│   ├── application.js
│   └── controllers
│       ├── application.js
│       └── ...
├── jobs
│   ├── application_job.rb
│   └── ...
├── mailers
│   ├── application_mailer.rb
│   └── ...
├── models
│   ├── application_record.rb
│   └── ...
├── policies
│   ├── application_policy.rb
│   └── ...
├── prompts
│   ├── application_prompt.rb
│   └── ...
├── services
│   ├── application_service.rb
│   └── ...
└── views
    └── ...
```

```
spec
├── factories
│   └── ...
├── helpers
├── jobs
│   └── ...
├── models
│   └── ...
├── policies
│   └── ...
├── requests
│   └── ...
├── services
│   └── ...
└── support
    ├── fixtures
    │   └── ...
    ├── helpers
    │   └── ...
    └── ...
```

**Key Points:**
- Each functionality group (models, controllers, policies, views) has its own directory.
- Classes maintain their original names (e.g., `User`, not `Users::User`).

## Models

- **User**: Uses Devise for authentication with custom `role` field
  - Location: `app/models/user.rb`
  - Roles: `user` (default), `admin`
  - Helper methods: `user?`, `admin?`
  - UUIDs as primary keys
  - Email automatically downcased on validation
  - Devise modules: database_authenticatable, registerable, recoverable, rememberable, validatable, trackable

## Authorization

- Uses ActionPolicy for authorization
- All controllers inherit from `ApplicationController` (in `app/controllers/`)
- Each model has its own policy file (e.g., `app/policies/user_policy.rb`)
- Unauthorized access redirects to root with I18n alert message

## Database Configuration

- Development/test: Single database
- Production: Multiple databases (primary, cache, queue, cable)
- Database names use `APP_NAME` environment variable
- Connection configured via environment variables (`PG_HOST`, `PG_USER`, `PG_PASSWORD`)

## Frontend Architecture

**Philosophy**: Hotwire-first approach with minimal custom JavaScript. Use Turbo for navigation and page updates, Stimulus for interactive enhancements, and ViewComponents for reusable UI.

**Stimulus Controllers** (`app/javascript/controllers/`)
- Minimal JavaScript setup
- Additional controllers as needed for interactive features
- Controllers need to be explicitly registered via `index.js`

**Icons**: Lucide Rails
- Render SVG icons with `lucide_icon("icon-name", class: "...")`
- 1000+ open-source icons available
- Used throughout components and views

**Styling**: Tailwind CSS 4.x + Basecoat UI
- Utility-first CSS framework
- Basecoat provides pre-built component styles
- Custom configuration in `tailwind.config.js`
- Built via `yarn build:css` (watch mode in development)

**JavaScript Bundling**: esbuild
- Fast, modern JavaScript bundler
- Entry point: `app/javascript/application.js`
- Built via `yarn build:js` (watch mode in development)

**Asset Serving**: Propshaft
- Modern Rails asset pipeline
- No fingerprinting in development
- Automatic fingerprinting in production

## Adding New Features

### When adding a new model:
1. **Migration**: Create migration file in `db/migrate/`
   - Use UUIDs for primary keys: `create_table :{plural}, id: :uuid`
   - Add foreign keys with UUIDs: `t.references :user, type: :uuid, foreign_key: true`
   - Run: `docker compose exec app bundle exec rails db:migrate`
   - Annotate models: `docker compose exec app bundle exec annotaterb models`

2. **Model**: Create model in `app/models/{model}.rb`
   - Add `frozen_string_literal: true` at top
   - Inherit from `ApplicationRecord`
   - Define associations, validations, enums
   - Use ActiveStorage for file uploads if needed

3. **Service**: Create service in `app/services/{service}_service.rb`
   - Add `frozen_string_literal: true` at top
   - Inherit from `ApplicationService`
   - If necessary, define an initializer that accepts arguments, calls `super()` and sets instance variables for the arguments
   - Define a `call` method that does not accept arguments, containing the business logic

4. **Policy**: Create policy in `app/policies/{model}_policy.rb`
   - Inherit from `ApplicationPolicy`
   - Define actions: `index?`, `show?`, `create?`, `update?`, `destroy?`
   - Define `relation_scope` for query scoping

5. **Controller**: Create controller in `app/controllers/{plural}_controller.rb`
   - Add `frozen_string_literal: true` at top
   - Authorize actions: `authorize! :{model_name}`
   - Use strong parameters

6. **Views**: Create views in `app/views/{plural}/`
   - `index.html.erb` - List view
   - `show.html.erb` - Detail view
   - `new.html.erb` - New record form
   - `edit.html.erb` - Edit record form
   - `_form.html.erb` - Shared form partial

7. **Routes**: Add routes in `config/routes.rb`
   - `resources :{plural}` for standard CRUD
   - Annotate routes: `docker compose exec app bundle exec annotaterb routes`

8. **Factory**: Create factory in `spec/factories/{plural}.rb`
   - Add traits for different states/types
   - Use FFaker for realistic fake data
   - Ensure all required fields have values

9. **Model Spec**: Create in `spec/models/{model}_spec.rb`
   - Test associations, validations, scopes, methods
   - Use `subject(:{model}) { build(:{model}) }`

10. **Request Spec**: Create in `spec/requests/{plural}_request_spec.rb`
    - Test all CRUD actions
    - Test authorization (signed in vs guest)
    - Use `sign_in(user)` helper

11. **Policy Spec**: Create in `spec/policies/{model}_policy_spec.rb`
    - Test all policy actions
    - Test relation scoping

12. **Seeds**: Create database seed in `db/seeds/` (production) or `db/seeds/development/`
    - Use a CSV for storing the data, and an import service (inheriting from `app/services/import_service.rb`) to load the data
    - Ensure idempotency (safe to run multiple times)

13. **Verify**: Run full test suite and linters
    - `docker compose exec app bundle exec rspec`
    - `docker compose exec app bundle exec rubocop -A`
    - `docker compose exec yarn run herb:format`
    - `docker compose exec i18n-tasks normalize`

### When adding a new Stimulus controller:
1. Create controller: `app/javascript/controllers/{name}_controller.js`
2. Inherit from Stimulus `Controller`
3. Register automatically via `index.js`
4. Use data attributes: `data-controller="{name}"`, `data-action="{event}->{name}#{method}"`
5. Keep JavaScript minimal (Hotwire-first approach)
