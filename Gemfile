# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "~> 4.0"

# OpenStruct [https://github.com/ruby/ostruct]
gem "ostruct"

# CGI [https://github.com/ruby/cgi]
gem "cgi"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1"

# BigDecimal library for Ruby
gem "bigdecimal"

# CSV library for Ruby
gem "csv"

# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"

# PostgreSQL relational database [https://www.postgresql.org/]
gem "pg", "~> 1.6"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]
gem "jsbundling-rails"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Bundle and process CSS [https://github.com/rails/cssbundling-rails]
gem "cssbundling-rails"

# A collection of icons [https://github.com/heyvito/lucide-rails]
gem "lucide-rails"

# HTML-aware ERB parser and tooling [https://github.com/marcoroth/herb]
gem "herb"

# Authorization policies for Rails
gem "action_policy"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: [:windows, :jruby]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cable"
gem "solid_cache"
gem "solid_queue"

# Monitor and manage background jobs and scheduled tasks [https://github.com/rails/mission_control-jobs]
gem "mission_control-jobs"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing"

# Active Storage validations [https://github.com/igorkasyanchuk/active_storage_validations]
gem "active_storage_validations"

# Flexible authentication solution for Rails [https://github.com/heartcombo/devise]
gem "devise"

# Pagination [https://github.com/ddnexus/pagy]
gem "pagy"

# Wizard controller framework [https://github.com/zombocom/wicked]
gem "wicked"

# AppSignal APM and error monitoring [https://github.com/appsignal/appsignal-ruby]
gem "appsignal"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: [:mri, :windows], require: "debug/prelude"

  # Application preloader for faster test boot [https://github.com/rails/spring]
  gem "spring"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # The Ruby linter/formatter [https://github.com/rubocop/rubocop]
  gem "rubocop"
  gem "rubocop-factory_bot"
  gem "rubocop-performance"
  gem "rubocop-rails"
  gem "rubocop-rspec"
  gem "rubocop-rspec_rails"

  # Ruby profiler [https://github.com/ruby-prof/ruby-prof]
  gem "ruby-prof", require: false
  gem "ruby-prof-flamegraph", github: "oozou/ruby-prof-flamegraph", require: false

  # Behavior-driven testing framework [https://github.com/rspec/rspec-rails]
  gem "rspec"
  gem "rspec-rails"

  # Shoulda-matchers [https://github.com/thoughtbot/shoulda-matchers]
  gem "shoulda-matchers"

  # Factory testing pattern [https://github.com/thoughtbot/factory_bot]
  gem "factory_bot"
  gem "factory_bot_rails"
  gem "ffaker"

  # Mock HTTP requests [https://github.com/bblimke/webmock]
  gem "webmock"

  # Defines temporary models and tables in specs [https://github.com/Casecommons/with_model]
  gem "with_model"
end

group :development do
  # Event-based file watcher for faster development [https://github.com/guard/listen]
  gem "listen"

  # Annotate models, routes, factories, and fixtures [https://github.com/drwl/annotaterb]
  gem "annotaterb", github: "drwl/annotaterb"

  # Manage missing and unused translations
  gem "i18n-tasks"

  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Process runner [https://github.com/ddollar/foreman]
  gem "foreman"
end
