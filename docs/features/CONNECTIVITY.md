# Connectivity

Scheduled job that checks connectivity to servers.

## Configuration

Configuration keys:
- [ ] `connectivity` (type: boolean, category: connectivity, default: true)
- [ ] `connectivity.interval` (type: integer, category: connectivity, default: 5, dependency: connectivity)

## Database model

### `servers` table

Columns:
- [ ] `probed_at` (datetime, null: true)
- [ ] `last_seen_at` (datetime, null: true)
- [ ] `error_class` (string, null: true)
- [ ] `error_message` (text, null: true)

Create the following files:
- [ ] `db/migrate/20220101000000_add_connectivity_to_servers.rb` — migration

Modify the following files:
- [ ] `app/models/server.rb` — model definition
  - [ ] Add a `online?` and `offline?` method
- [ ] `spec/models/server_spec.rb` — model spec

- [ ] `spec/factories/models.rb` — factory definition
  - [ ] Add a :online and :offline trait

## User interface

Views:
- [ ] Index page (`/servers`)
- [ ] Add an additional icon column in the front with a status indicator
  - [ ] Red dot for offline, green dot for online (last seen at is not null)
  - [ ] Tooltip with error message or last seen time

Notes:
- [ ] Don't add column if feature is disabled

## Services

Services:
- [ ] `Servers::ConnectionService` — Set the probed_at, last_seen_at, and error_class/message for a server

- [ ] `Servers::ConnectionJob` — Run the service every `connectivity.interval` seconds
- [ ] `Servers::ConnectionScheduleJob` — Run the service every minute, but only if connectivity is enabled, scheduling ConnectionJob for each server that hasn't been probed in the configured interval

## Seeds

Update the seeds, adding these columns to servers.csv and the import/export services (including specs)
