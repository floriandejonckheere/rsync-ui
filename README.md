<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/logo-dark.png">
    <img alt="Rsync UI" src="docs/images/logo-light.png" width="430">
  </picture>
</p>

<p align="center">
  <a href="https://github.com/floriandejonckheere/rsync-ui/actions/workflows/ci.yml"><img alt="Continuous Integration" src="https://github.com/floriandejonckheere/rsync-ui/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/floriandejonckheere/rsync-ui/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/floriandejonckheere/rsync-ui?label=Latest%20release"></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/floriandejonckheere/rsync-ui"></a>
</p>

Rsync UI is a web application that lets you create, schedule, and execute file synchronization jobs with just a few clicks, powered by [rsync](https://github.com/RsyncProject/rsync).

## Highlights

- Dashboard for job health, activity, schedules, and storage
- Synchronization jobs for local and remote destinations
- Fully customizable command-line arguments
- Automation through scheduled jobs
- Remote server management with SSH key deployment and resource usage visibility
- Custom pre-/post-synchronization hooks
- Builtin customizable notifications
- Real-time synchronization progress
- SSH command auditing for security and compliance

## Screenshots

<a href="screenshots/dashboard.png"><img src="screenshots/dashboard.png" width="49%"></a>
<a href="screenshots/activity-log.png"><img src="screenshots/activity-log.png" width="49%"></a>
<a href="screenshots/servers.png"><img src="screenshots/servers.png" width="49%"></a>
<a href="screenshots/repositories.png"><img src="screenshots/repositories.png" width="49%"></a>
<a href="screenshots/jobs.png"><img src="screenshots/jobs.png" width="49%"></a>
<a href="screenshots/notifications.png"><img src="screenshots/notifications.png" width="49%"></a>
<a href="screenshots/job.png"><img src="screenshots/job.png" width="49%"></a>

<br />

<a href="screenshots/job-repositories.png"><img src="screenshots/job-repositories.png" width="24%"></a>
<a href="screenshots/job-notifications.png"><img src="screenshots/job-notifications.png" width="24%"></a>
<a href="screenshots/job-include-exclude.png"><img src="screenshots/job-include-exclude.png" width="24%"></a>
<a href="screenshots/job-custom.png"><img src="screenshots/job-custom.png" width="24%"></a>
<a href="screenshots/job-basic.png"><img src="screenshots/job-basic.png" width="24%"></a>
<a href="screenshots/job-advanced.png"><img src="screenshots/job-advanced.png" width="24%"></a>
<a href="screenshots/job-hooks.png"><img src="screenshots/job-hooks.png" width="24%"></a>

> [!NOTE]
> Artificial Intelligence tooling is used during the development of this project. All generated code is thoroughly reviewed, tested, and verified manually to ensure the highest quality and security standards.

## Getting started

Rsync UI is distributed as a Docker image and is meant to be run with Docker compose.

### Requirements

- Docker with the Docker compose plugin
- A reverse proxy that terminates TLS (see [Reverse proxy](#reverse-proxy))

### Installation

1. Create a `compose.yml` file:

   ```yml
   x-app: &app
     image: ghcr.io/floriandejonckheere/rsync-ui:latest
     restart: unless-stopped
     volumes:
       - rsync_ui:/app/storage/ # Application storage (rsync logs)
       - /path/to/storage:/data/storage:ro # Local directory to back up (read-only)
       - /path/to/backup:/data/backup:rw # Local directory to back up to (read-write)
     environment:
       SECRET_KEY_BASE: my-secret # Application secret key
       ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY: my-secret # Encryption secret key
       ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY: my-secret # Encryption secret key
       ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT: my-secret # Encryption secret key

       PG_HOST: postgres
       PG_USER: rsync_ui
       PG_PASSWORD: my-password
       PG_DATABASE: rsync_ui

       APP_HOST: rsync-ui.example.com # Public hostname of the application
       APP_EMAIL: rsync-ui@example.com # Sender address of emails sent by the application

       ADMIN_EMAIL: admin@example.com # Default administrator account
       ADMIN_PASSWORD: my-admin-password # Default administrator password
     depends_on:
       postgres:
         condition: service_healthy

   services:
     web:
       <<: *app
       ports:
         - "127.0.0.1:3000:3000"

     worker:
       <<: *app
       command: bin/jobs

     postgres:
       image: postgres:18
       restart: unless-stopped
       volumes:
         - postgres:/var/lib/postgresql/18/docker/
       environment:
         POSTGRES_USER: postgres
         POSTGRES_PASSWORD: my-postgres-password
       healthcheck:
         test: ["CMD", "pg_isready", "-U", "postgres"]
         interval: 2s
         timeout: 5s
         retries: 30

   volumes:
     postgres:
     rsync_ui:
   ```

   Generate each secret with `openssl rand -hex 32`, and replace the passwords with strong, unique values.

2. Start the database:

   ```sh
   docker compose up -d postgres
   ```

3. Create the database user and database for the application, using the `PG_USER`, `PG_PASSWORD` and `PG_DATABASE` values from step 1:

   ```sh
   docker compose exec postgres psql -U postgres \
     -c "CREATE USER rsync_ui WITH PASSWORD 'my-password';" \
     -c "CREATE DATABASE rsync_ui OWNER rsync_ui;"
   ```

4. Start the application:

   ```sh
   docker compose up -d
   ```

   The database schema is created automatically on first start, and the administrator account is created using `ADMIN_EMAIL` and `ADMIN_PASSWORD`.

5. Configure your reverse proxy to forward `https://rsync-ui.example.com` to port 3000, and sign in with the administrator account.

### Reverse proxy

Rsync UI does not handle TLS itself, and serves plain HTTP on port 3000.
Run it behind a reverse proxy (e.g. [Caddy](https://caddyserver.com/), [Traefik](https://traefik.io/) or [nginx](https://nginx.org/)) that terminates TLS.
The reverse proxy must:

- Serve the application on the hostname configured in `APP_HOST`
- Set the `X-Forwarded-Proto` header
- Support WebSocket connections (used for real-time updates)

For example, using Caddy (which sets up TLS certificates automatically):

```
rsync-ui.example.com {
  reverse_proxy localhost:3000
}
```

### Local storage

Local directories are mounted into the container under `/data`, and can be added as local repositories in the application (e.g. `/data/storage`).

The application runs as user and group ID `1000` inside the container, so this user needs read access to source directories and write access to destination directories.

### Configuration

Besides the variables in the example above, the following optional environment variables are available:

| Variable | Default | Description |
|----------|---------|-------------|
| `RAILS_LOG_LEVEL` | `info` | Log level (`debug`, `info`, `warn`, `error`, `fatal`) |
| `JOB_CONCURRENCY` | `1` | Number of background job worker processes |
| `RAILS_MAX_THREADS` | `5` | Number of web server threads (also the database connection pool size) |
| `MISSION_CONTROL` | `0` | Set to `1` to enable the background job dashboard for administrators |
| `SKIP_CREDENTIALS_CHECK` | `0` | Set to `1` to skip checking the required environment variables on startup |
| `SKIP_CONFIGURATION_CHECK` | `0` | Set to `1` to skip checking the application configuration on startup |
| `SKIP_SSH_CONFIG_SYNC` | `0` | Set to `1` to skip regenerating the SSH configuration on startup |

### Health check

The application exposes a health check endpoint at `/up`, which returns HTTP 200 when the application is running, and HTTP 500 otherwise.

### Upgrading

Pull the latest image and restart the containers:

```sh
docker compose pull
docker compose up -d
```

Database migrations are run automatically on startup.
Read the [changelog](CHANGELOG.md) before upgrading.

### Backups

All application data (servers, repositories, jobs and their history) is stored in the PostgreSQL database.
Back up the database regularly, for example:

```sh
docker compose exec postgres pg_dump -U postgres rsync_ui > rsync_ui.sql
```

Server credentials (passwords and SSH keys) are encrypted in the database using the `ACTIVE_RECORD_ENCRYPTION_*` keys.
Store these keys together with your backups: without them, the encrypted credentials cannot be restored.

## Development

First, ensure you have a working Docker environment with the Docker compose plugin.

### Start the application

Build the images and start the containers:

```sh
docker compose up -d
```

On startup, the database is created, migrated, and seeded with sample data.
The application is now available at [http://localhost:3000](http://localhost:3000). Sign in with the administrator account configured in `.development.env`.

### Development environment

The development environment includes three fake SSH servers that simulate remote storage targets, seeded with realistic data so jobs can be run end-to-end without real infrastructure.

| Container | Script | Mount |
|-----------|--------|-------|
| `nas` | `docker/ssh/init-nas.sh` | `./tmp/data/nas` → `/data` |
| `backup` | `docker/ssh/init-backup.sh` | `./tmp/data/backup` → `/backup` |
| `mirror` | `docker/ssh/init-mirror.sh` | `./tmp/data/mirror` → `/backup` |

The app container stores all local repository data under `./tmp/data/app` (mounted to `/data`).

The following jobs are pre-seeded and can be run against these servers:

| Job | Source | Destination | Schedule |
|-----|--------|-------------|----------|
| Docker replica | `Docker` (local) | `Docker Replica` (local) | Every 5 minutes, disabled |
| Home backup | `Home` (local) | `Home backup` (Backup server) | Daily at 02:00 |
| Projects backup | `Projects` (local) | `Projects backup` (Backup server) | Daily at 02:00 |
| NAS photos sync | `NAS Photos` (NAS server) | `Photos` (local) | Weekly on Sunday at 03:00 |
| Photos mirror sync | `Photos` (local) | `Photos mirror` (Mirror server) | Weekly on Monday at 03:00 |

Source repositories are pre-populated with representative data. Destination repositories start empty and are filled when their job runs.

To reset all destination repositories back to their initial empty state, run from the project root:

```sh
docker/reset.sh
```

### Updating

Run the `bin/update` script to pull and rebuild the images, install the Ruby and JavaScript dependencies, and restart the application:

```sh
bin/update
```

### Useful commands

```sh
docker compose logs -f app worker                                       # Follow application and background worker logs
docker compose exec app bash                                            # Open a shell in the application container
docker compose exec app bundle exec rails console                       # Open a Rails console
docker compose exec app bundle exec rails db:migrate                    # Run database migrations
docker compose exec app bundle exec rails database:seed                 # Seed the database with sample data
docker compose exec app bundle exec rspec                               # Run the test suite
docker compose exec app bundle exec rspec spec/path/to/file_spec.rb:12  # Run a single test
docker compose exec app bundle exec rubocop                             # Lint Ruby code
docker compose exec app yarn herb:format                                # Format ERB templates
docker compose exec app bundle exec brakeman                            # Run a security scan
```

See [docs/COMMANDS.md](docs/COMMANDS.md) for more commands.

### Debugging

Call `binding.break` anywhere in the source code to start a debugger.

### Environment variables

When adding application environment variables, do not forget to add them in the following places:

- `.development.env`
- `config/initializers/credentials.rb` (if the variable is required in production)
- The [Installation](#installation) or [Configuration](#configuration) section of this README

### Repository secrets

The CI workflow needs the following repository secrets to push Docker images to the GitHub Container Registry:

- `GHCR_USER` (GitHub Container Registry username)
- `GHCR_TOKEN` (GitHub Container Registry token)

Create a [personal access token on GitHub](https://github.com/settings/tokens/new?description=Rsync+UI+(CI)&scopes=repo,write:packages).

The cleanup workflow deletes untagged images from the registry every Sunday (and can be run manually, by default as a dry run).
It uses the workflow token, so the repository needs the `Admin` role in the package's "Manage Actions access" settings.

### Releasing

Add your changes to the `Unreleased` section of the [changelog](CHANGELOG.md) as you go.
To release a version (`vMAJOR.MINOR.PATCH`, optionally with a pre-release suffix, e.g. `v1.0.0-rc.1`), run from an up-to-date, clean `main` branch:

```sh
bin/release v1.0.0
```

The script:

1. Writes the version to `lib/rsync_ui/version.rb` (using `bin/version`)
2. Moves the `Unreleased` changelog entries to a new version section (dated today) and updates the comparison links (using `bin/changelog`)
3. Commits the changes (`Bump version to v1.0.0`) and tags the commit `v1.0.0`
4. Shows the release notes, and asks for confirmation before pushing `main` and the tag to GitHub

Once the tag passes the tests, the CI workflow verifies that the tag matches the version and changelog, builds a Docker image and pushes it to the registry (e.g. `ghcr.io/floriandejonckheere/rsync-ui:v1.0.0`), and creates a GitHub release with the changelog entries of the version as release notes (marked as pre-release if the version has a suffix).
Every push to `main` also builds and pushes the `latest` image.

The script refuses to release if the `Unreleased` section is empty.

## License

Copyright 2026 Florian Dejonckheere
