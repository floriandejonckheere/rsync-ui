# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a production-ready Rails 8.0 application template with modern frontend tooling, authentication, and authorization.

## Tech Stack

- **Ruby**: 4.0
- **Rails**: 8.0.3
- **Database**: PostgreSQL 18
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS 4.x with Basecoat UI, ViewComponent
- **Icons**: Lucide
- **Authentication**: Devise
- **Authorization**: ActionPolicy
- **Testing**: RSpec with FactoryBot, Shoulda Matchers, WebMock, Timecop
- **Background Jobs**: Solid Queue with Mission Control
- **Caching**: Solid Cache (backed by database)
- **WebSockets**: Solid Cable (Action Cable backend)
- **File Storage**: ActiveStorage
- **Asset Pipeline**: Propshaft, jsbundling-rails (esbuild), cssbundling-rails (Tailwind)
- **ERB Tooling**: Herb (HTML-aware ERB parser, linter, and formatter)
- **CI/CD**: GitHub Actions with comprehensive checks

## Key Conventions

### General

- All Ruby files use `frozen_string_literal: true`
- Models are annotated with schema information at the bottom (done automatically via `rails db:migrate`)
- Routes are annotated with `# == Route Map` comments at the top of controllers
- Authorization is required on all actions (via `verify_authorized` in ApplicationController)
- Modern browsers only (enforced by `allow_browser versions: :modern`)
- Use `binding.break` for debugging (debug gem)
- Always prompt for confirmation before running `rails db:migrate`
- ERB templates use Herb for HTML-aware parsing and tooling (configured in `.herb.yml`)
- Always translate user-facing strings using I18n (no hardcoded strings in views or controllers)
- When completing a single task or feature, check it off in [docs/PROJECT.md](docs/PROJECT.md)
- Assume one (and exactly one) role when answering the user's query. See the [docs/ROLES.md](docs/ROLES.md) file for more information

### Before committing

Run these checks selectively before each commit, based on the set of modified files:

1. Ensure relevant tests pass: `docker compose exec app bundle exec rspec <FILES>` (if any `.rb` files were modified)
2. Ensure no style violations are present: `docker compose exec app bundle exec rubocop <FILES>` (if any `.rb` files were modified)
3. Ensure ERB formatting is correct: `docker compose exec app yarn herb:format` (if any `.html.erb` files were modified)
4. Update model annotations: `docker compose exec app bundle exec annotaterb models` (if any files in `db/migrate` were modified)
5. Update route annotations: `docker compose exec app bundle exec annotaterb routes` (if `config/routes.rb` was modified)
6. Clean up i18n files: `docker compose exec app bundle exec i18n-tasks normalize` (if any files in `config/locales` were modified)

**Note**: CI also enforces these checks.

## Version control

### Commits

- **Atomic commits**: Each commit should represent a single logical change. Small, focused commits are preferred.
- **Commit messages**: Use clear, descriptive messages in the imperative mood (e.g., "Add user authentication" instead of "Added user authentication").
- **Cohesion**: Keep related changes together (e.g., a model change and its corresponding migration and tests).

### Branching and PRs

- **Feature branches**: Work on feature branches named `feature-name` or `issue-name`.
- **Merge strategy**: Fast-forward merge is preferred for merging feature branches to keep a consistent main history without merge commits.
- **PR Descriptions**: Provide a brief summary of the changes and any specific testing instructions.

### Conventions

Create one commit:
- When installing additional gems or dependencies, per gem/dependency, with commit message `Add <gem> gem` or `Add <package> dependency`.
- When modifying the database schema (e.g. creating a table or adding a column to an existing table), per schema change/migration file.

## Project Management

The current status of the tasks and features is tracked in [docs/PROJECT.md](docs/PROJECT.md).
Refer to the document for details on completed, in-progress, and upcoming work.

## Documentation

For detailed information on specific topics, see:

- **[docs/COMMANDS.md](docs/COMMANDS.md)** - Common commands used during development
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Application structure, models, authorization, frontend architecture, and adding new features
- **[docs/STYLE.md](docs/STYLE.md)** - Ruby and ERB code style conventions
- **[docs/PATTERNS.md](docs/PATTERNS.md)** - Common patterns and best practices
- **[docs/TESTING.md](docs/TESTING.md)** - Testing setup, conventions, patterns, and CI/CD pipeline
- **[docs/SECURITY.md](docs/SECURITY.md)** - Security best practices and authorization patterns
- **[docs/PERFORMANCE.md](docs/PERFORMANCE.md)** - Performance optimization tips and background job patterns
- **[docs/DATABASE.md](docs/DATABASE.md)** - Database conventions, migrations, and ActiveStorage patterns
