# Development Commands

**Note**: This application runs in Docker. All commands should be executed using `docker compose`.

## Initial Setup
```bash
docker compose up -d                                 # Start Docker environment (postgres, app, worker)
docker compose exec -u root --rm app bundle install  # Install Ruby gems
docker compose exec -u root --rm app yarn install    # Install JS dependencies
docker compose exec app bundle exec rails db:setup   # Setup database
```

**Docker Services:**
- `app` - Rails application (runs Foreman with web, js, css processes)
- `postgres` - PostgreSQL 18
- `worker` - Background job processor

## Running the App
```bash
docker compose up            # Start all services (app runs foreman with web, js, css watch)
docker compose up -d         # Start all services in background
docker compose logs -f app   # Follow app logs
docker compose down          # Stop all services
```

## Accessing the App Container
```bash
docker compose exec app bash              # Open shell in running app container
docker compose run --rm app bash          # Run one-off command in new container
docker compose run -u root --rm app bash  # Run as root (for system changes)
```

## Database
```bash
docker compose exec app bundle exec rails db:setup                   # Create, migrate, seed database
docker compose exec app bundle exec rails db:migrate                 # Run migrations
docker compose exec app bundle exec rails database:seed              # Run all seeds (production + development)
docker compose exec app bundle exec rails database:seed:production   # Production seeds only
docker compose exec app bundle exec rails database:seed:development  # Development seeds only
docker compose exec app bundle exec rails db:reset                   # Drop, create, migrate, seed
```

See [docs/DATABASE.md](docs/DATABASE.md) for detailed database conventions and patterns.

## Testing
```bash
docker compose exec app bundle exec rspec                                # Run all specs
docker compose exec app bundle exec rspec spec/models/                   # Run all model specs
docker compose exec app bundle exec rspec spec/models/model_spec.rb      # Run model model specs
docker compose exec app bundle exec rspec spec/path/to/file_spec.rb:12   # Run specific test at line 12
```

See [docs/TESTING.md](docs/TESTING.md) for comprehensive testing documentation.

## Linting & Security
```bash
docker compose exec app bundle exec rubocop     # Run Rubocop linter
docker compose exec app bundle exec rubocop -A  # Auto-correct safe and unsafe offenses
docker compose exec app bundle exec brakeman    # Security vulnerability scan
```

See [docs/STYLE.md](docs/STYLE.md) for code style conventions.

## ERB Tooling (Herb)
```bash
docker compose exec app bundle exec herb analyze app  # Analyze all ERB templates
docker compose exec app bundle exec herb parse [file] # Parse a specific ERB file
docker compose exec app bundle exec herb lex [file]   # Lex a specific ERB file
docker compose exec app bundle exec herb ruby [file]  # Extract Ruby from ERB file
docker compose exec app bundle exec herb html [file]  # Extract HTML from ERB file
```

Configuration is in `.herb.yml` in the project root.

## Bundle/Dependency Management
```bash
docker compose exec -u root --rm app bundle install   # Install gems (requires root)
docker compose exec -u root --rm app bundle update    # Update gems (requires root)
docker compose exec -u root --rm app yarn install     # Install JS dependencies (requires root)
docker compose exec -u root --rm app yarn upgrade     # Update JS dependencies (requires root)
```

## Asset Compilation
```bash
docker compose exec app yarn build           # Build both JS and CSS
docker compose exec app yarn build:js        # Build JavaScript with esbuild
docker compose exec app yarn build:css       # Build CSS with Tailwind
```

## Annotations
```bash
docker compose exec app bundle exec annotaterb models     # Annotate models with schema info
docker compose exec app bundle exec annotaterb routes     # Annotate routes
```

## Rails Console & Other Rails Commands
```bash
docker compose exec app bundle exec rails console           # Open Rails console
docker compose exec app bundle exec rails routes            # View routes
docker compose exec app bundle exec rails about             # View Rails/Ruby versions
docker compose exec app bundle exec rails routes -g models  # View routes for models controller
```

## Background Job Management
```bash
docker compose exec app bundle exec rails mission_control:jobs  # Access job management UI (runs on separate port)
docker compose logs -f worker                                   # View background worker logs
docker compose restart worker                                   # Restart background worker
```
