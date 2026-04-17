# Rsync UI

[![Continuous Integration](https://github.com/floriandejonckheere/rsync-ui/actions/workflows/ci.yml/badge.svg)](https://github.com/floriandejonckheere/rsync-ui/actions/workflows/ci.yml)
[![Continuous Deployment](https://github.com/floriandejonckheere/rsync-ui/actions/workflows/cd.yml/badge.svg)](https://github.com/floriandejonckheere/rsync-ui/actions/workflows/cd.yml)

![Release](https://img.shields.io/github/v/release/floriandejonckheere/rsync-ui?label=Latest%20release)
![Deployment](https://img.shields.io/github/deployments/floriandejonckheere/rsync-ui/production?label=Deployment)

Rsync UI is a web application that lets you create, schedule, and execute file synchronization jobs with just a few clicks, backed by [rsync](https://github.com/RsyncProject/rsync).

## Setup

First, ensure you have a working Docker environment.

### Start the Application

Pull the images and start the containers:

```
docker-compose up -d
```

Set up the PostgreSQL database:

```
docker-compose exec app bundle exec rails db:setup
```

Load sample data into the PostgreSQL database:

```
docker-compose exec app bundle exec rails database:seed
```

The application is now available at [http://localhost:3000](http://localhost:3000).

## Development

Use the `bin/update` script to update your development environment dependencies.

## Debugging

Call `binding.break` anywhere in the source code to start a debugger.

## Testing

Run the test suite:

```
rspec
```

## Secrets

### Repository secrets

Secrets for release and deployment:

- `GHCR_USER` (Github Container Registry username)
- `GHCR_TOKEN` (Github Container Registry token)

Create a [personal access token on GitHub](https://github.com/settings/tokens/new?description=Rsync+UI+(CI)&scopes=repo,write:packages).

Secrets for deployment:

- `SSH_HOST` (deployment host)
- `SSH_USER` (deployment user)
- `SSH_KEY` (private key)

### Environment secrets

Secrets for deployment:

- `SECRET_KEY_BASE` (application secret)

- `PG_HOST` (PostgreSQL host)
- `PG_USER` (database username)
- `PG_PASSWORD` (database password)

- `APP_HOST` (application hostname)
- `APP_EMAIL` (application email)

- `ADMIN_EMAIL` (administrator account email)
- `ADMIN_PASSWORD` (administrator account password)

- `POSTGRES_PASSWORD` (postgres user password, only for postgres container)

- `APPSIGNAL_API_KEY`

When adding more application environment variables, do not forget to add them in the following files, and on GitHub as environment secrets:

- `.development.env`
- `.github/workflows/cd.yml`
- `ops/compose.yml`

## Releasing

Update the changelog and bump the version in `lib/rsync_ui/version.rb`.
Create a tag for the version and push it to Github.
A Docker image will automatically be built and pushed to the registry.

```sh
nano lib/rsync_ui/version.rb
git add lib/rsync_ui/version.rb
git commit -m "Bump version to v1.0.0"
git tag v1.0.0
git push origin master
git push origin v1.0.0
```

## License

Copyright 2026 Florian Dejonckheere
