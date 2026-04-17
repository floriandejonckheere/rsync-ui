# Database

This document describes database conventions and patterns.

## Database Conventions

- **Primary Keys**: Always use UUIDs for better security and distributed systems
- **Foreign Keys**:
  - Always use `type: :uuid` when referencing UUID primary keys
  - Always specify `on_delete: :cascade` to ensure referential integrity at the database level
  - Example: `t.references :{model}, null: false, foreign_key: { on_delete: :cascade }, type: :uuid`
- **Timestamps**: Enabled by default (`created_at`, `updated_at`)
- **Soft Deletes**:
  - Use `discarded_at` (datetime) + `Discard` concern for discardable models
  - Add an index for common access patterns (e.g., `[:user_id, :discarded_at]`)
- **Indexes**: Add indexes for foreign keys and frequently queried columns
- **NOT NULL**: Use `null: false` for required columns
- **Defaults**: Set sensible defaults in migrations (e.g., `default: 0`)

## Database Commands

```bash
docker compose exec app bundle exec rails db:setup                   # Create, migrate, seed database
docker compose exec app bundle exec rails db:migrate                 # Run migrations
docker compose exec app bundle exec rails database:seed              # Run all seeds (production + development)
docker compose exec app bundle exec rails database:seed:production   # Production seeds only
docker compose exec app bundle exec rails database:seed:development  # Development seeds only
docker compose exec app bundle exec rails db:reset                   # Drop, create, migrate, seed
```

Seeds are organized in:
- `db/seeds/*.rb` - Production seeds
- `db/seeds/development/*.rb` - Development seeds
