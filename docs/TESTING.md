# Testing

This document describes the testing setup, conventions, and CI/CD pipeline.

## Testing Setup

**Framework**: RSpec with Rails
- Configuration in `spec/rails_helper.rb` and `.rspec`
- Automatically loads all support files from `spec/support/**/*.rb`
- Uses transactional fixtures for speed
- Database cleaner strategy: transaction

**FactoryBot Factories** (`spec/factories/`)
- `users.rb`:
  - Default factory creates standard user
  - `:admin` trait for admin users
  - Generates unique emails with FFaker

**Testing Libraries**:
- **Shoulda Matchers**: Simplifies ActiveRecord/ActiveModel testing
  - `it { is_expected.to validate_presence_of(:title) }`
  - `it { is_expected.to belong_to(:user) }`
- **WebMock**: HTTP request stubbing (configured to disallow real requests)
- **ActiveSupport::Testing::TimeHelpers**: Time manipulation for time-dependent tests
- **ActionPolicy RSpec**: Policy testing helpers
  - `have_authorized_scope` matcher

**Test Organization**:
- Type-based structure mirrors `app/` directory
- Request helpers: `sign_in(user)` for authenticated request specs

## Testing Conventions

- Specs never need `require "rails_helper"` as it's included in `.rspec`
- Specs are organized by type in `spec/{type}/`
- Model specs go in `spec/models/{model}_spec.rb`
- Request specs go in `spec/requests/{controller}_request_spec.rb`
- Policy specs go in `spec/policies/{policy}_spec.rb`
- Service specs go in `spec/services/{service}_spec.rb`
- Factories are shared and go in `spec/factories/`
- Specs should always have a subject defined with `subject(:my_object) { ... }`, and use the factory if possible
- Use `build(:factory)` for unsaved records, `create(:factory)` for persisted records
- Prefer `build` in model specs for validation tests (faster, no database writes)
- Use `create` in request/integration specs when you need persisted data
- Leverage factory traits for different states: `create(:user, :admin)`
- Never stub `Configuration.get` directly with `allow(Configuration).to receive(:get)`. The `Configuration` model is a thin wrapper around persisted settings; mocking it bypasses the real read/write path and produces brittle, leaky tests. Always go through the `with_configuration` helper instead — it sets the value before the example and restores the original after, so configuration changes never leak between examples.
- When testing different configurations, use the `with_configuration` helper:
  ```ruby
  context "when notifications are enabled" do
    with_configuration "notifications" => true
  
    it "shows the notifications menu item" do
      get root_path
  
      expect(response.body).to include I18n.t("notifications.title")
    end
  end
  
  context "when notifications are disabled" do
    with_configuration "notifications" => false
  
    it "hides the notifications menu item" do
      get root_path
  
      expect(response.body).not_to include I18n.t("notifications.title")
    end
  end
  ```

## Browser testing

In order to test or validate something using the running app, use [http://localhost:3000](http://localhost:3000) once `docker compose up` is running.

**Default logins** (seeded via `db:setup`/`database:seed:development`):

- Email: `admin@example.com`
- Password: `password`

Tips for an AI agent validating changes live in a browser:

- Start (or confirm) the stack with `docker compose up -d` and tail `docker compose logs -f app` to catch server-side errors while clicking through the UI.
- Development seeds (`db/seeds/development/`) also create sample servers and users beyond the admin account — check the CSVs there if a test needs more varied data.
- If a page 500s, the Rails error page and `docker compose logs -f app` are more informative than the browser console; check both.
- After seed/model changes, re-run `docker compose exec app bundle exec rails db:seed` (or `db:reset` for a clean slate) so the browser session reflects current data.
- CSS/JS changes are picked up by the `css`/`js` watch processes inside the `app` container's Foreman setup; a browser refresh is enough, no rebuild needed.

## Testing Best Practices

- Test behavior, not implementation
- Multiple assertion per test (when they are related, for example testing multiple attributes on a model)
- Use descriptive `describe` and `context` blocks
- Use `let` for memoized variables, `let!` for eager evaluation
- Sign in users in request specs: `before { sign_in(user) }`
- Use Shoulda Matchers for simple validations/associations
- Test the happy path first, then add contexts for alternative and failure paths
- Test edge cases and error conditions
- Mock external HTTP requests with WebMock
