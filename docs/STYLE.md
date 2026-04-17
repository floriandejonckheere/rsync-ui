# Code Style

This document describes the code style conventions used in the application.

## Ruby Style (Rubocop)

- Double quotes for strings
- Trailing commas for multiline structures
- Bracket syntax for symbol/word arrays: `["foo", "bar"]`, `[:foo, :bar]`
- Indented multiline method calls
- Max method length: 20 lines (excluding migrations)
- Max ABC size: 30 (excluding migrations)
- Target Ruby version: 4.0
- Plugins enabled: factory_bot, performance, rails, rspec, rspec_rails

## ERB Style (Herb)

- HTML-aware ERB parsing and linting
- Configuration in `.herb.yml`
- Format checking in CI (must pass `yarn run herb:lint`)
- Analyze templates: `bundle exec herb analyze app`

## General Code Conventions

- All Ruby files use `frozen_string_literal: true`
- Models are annotated with schema information at the bottom (done automatically via `rails db:migrate`)
- Routes are annotated with `# == Route Map` comments at the top of controllers
- Authorization is required on all actions (via `verify_authorized` in ApplicationController)
- Modern browsers only (enforced by `allow_browser versions: :modern`)
- Use `binding.break` for debugging (debug gem)
- ERB templates use Herb for HTML-aware parsing and tooling (configured in `.herb.yml`)
