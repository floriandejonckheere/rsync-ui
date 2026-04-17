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
