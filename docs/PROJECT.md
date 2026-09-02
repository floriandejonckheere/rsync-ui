# Rsync UI

Rsync UI is a web application that lets you create, schedule, and execute file synchronization jobs with just a few clicks, powered by [rsync](https://github.com/RsyncProject/rsync).

## Features

### Dashboard

The dashboard provides a comprehensive overview of your synchronization jobs, including health, activity, schedules, and storage.
Organized in rows, 4 cards per row.

First row:
- One card (double width, 2 cards wide) with the overall status: health, degraded, or unknown (over the past 24 hours)
  - Healthy if all (non-running) jobs have ran successfully
  - Degraded if any job has failed
  - Unknown if no jobs have run yet
  - A gauge representing the number of failed and completed jobs
- One card with the last job run, started at, duration, ended at, and status
- One card with the next scheduled job

Second row:
- One card with a gauge representing the number of repositories (local and remote)
- One card with a gauge representing the cumulated used and total storage

Third row:
- Per server, one card with the name and the resource usage (already exists)

### Browse repositories

Allow the user to browse the repositories and their contents.
This is useful for debugging and troubleshooting.
For local repositories, the contents can be viewed directly in the browser.
For remote repositories, the server should be mounted as a local directory, and the contents can be viewed in the browser.

- [ ] Implement repository browsing
  - [ ] Local repositories
  - [ ] Remote repositories

### Archiving

- [ ] Add `archived_at` column
  - [ ] `job_runs` table
  - [ ] `jobs` table
  - [ ] `repositories` table
  - [ ] `servers` table
- [ ] Add `Archivable` concern
  - [ ] `archive!` method sets `archived_at` on table and dependent tables (e.g. archiving server also archives related repositories)
- [ ] Add archived tab
  - [ ] Job runs page
  - [ ] Jobs page
  - [ ] Repositories page
  - [ ] Servers page
- [ ] Disable features for archived tables
  - [ ] Disable connectivity polling for archived servers
  - [ ] Disable scheduling for archived jobs

### Smaller TODOs

- [ ] Make application responsive
- [ ] Make job run immutable and reproducible
  - [ ] Temporary: lock job, repositories, hooks, notifications rows when executing job
  - [ ] Save hooks in the database
  - [ ] Save repository in the database
  - [ ] Save notifications in the database
- [ ] Allow retrying jobs, or automatic retry (e.g. with incremental/exponential backoff)
- [ ] Update branding
- [ ] Prevent command injection in "custom rsync command" and "custom rsync options"
- [ ] Allow custom scripts on startup (e.g. installing packages, https://www.linuxserver.io/blog/2019-09-14-customizing-our-containers)
- [ ] Implement support for OAuth2 authentication
- [ ] Improve auditing: add login, change password, notification sending
- [ ] Do not bind postgres to port 5432, otherwise you can't use git worktrees
- [ ] Audit codebase
- [ ] SSH config: write password/private key only when invoking SSH commands
- [ ] Allow discovery of partitions/disks on the server and measure resource usage per partition/disk
- [ ] Too many `SolidCable::TrimJob` jobs when using ActionCable
- [ ] Only run SyncSSHConfig job periodically, not on startup
- [ ] Throttle/rate limit status updates
- [ ] Make streaming job output fixed height, but scrolling (and anchored to the bottom)
- [ ] Drop `Net::SSH` in favor of plain `ssh`
- [ ] Make the job wizard breadcrumbs clickable
- [ ] Implement backoff for servers: after N failed retries, disable connectivity/resource usage

- [ ] Optimize log streaming:

```
rsync_ui_worker-1  | [ActiveJob] [JobRuns::ExecuteJob] [86647f14-24c5-45b8-9094-a048df096043] [ActionCable] Broadcasting to job_run_logs_b2c7c404-d1cc-44c0-ab4b-fee3a6100e88: {type: "log", content: "admin/2021/May/IMG_20210516_125741.jpg.xmp\n"}
rsync_ui_worker-1  | [ActiveJob] [JobRuns::ExecuteJob] [86647f14-24c5-45b8-9094-a048df096043]   SolidCable::Message Insert (0.5ms)  INSERT INTO "solid_cable_messages" ("created_at","channel","payload","channel_hash") VALUES ('2026-09-02 16:10:24.749403', '\x6a6f625f72756e5f6c6f67735f62326337633430342d643163632d343463302d616234622d666565336136313030653838', '\x7b2274797065223a226c6f67222c22636f6e74656e74223a2261646d696e2f323032312f4d61792f494d475f32303231303531365f3132353734312e6a70672e786d705c6e227d', 8237753626498216333) ON CONFLICT  DO NOTHING RETURNING "id"
rsync_ui_worker-1  | [ActiveJob] [JobRuns::ExecuteJob] [86647f14-24c5-45b8-9094-a048df096043]   TRANSACTION (2.7ms)  COMMIT
rsync_ui_worker-1  | [ActiveJob] [JobRuns::ExecuteJob] [86647f14-24c5-45b8-9094-a048df096043]   Configuration::Boolean Load (0.4ms)  SELECT "configurations".* FROM "configurations" WHERE "configurations"."type" = $1 AND "configurations"."key" = $2 LIMIT $3  [["type", "Configuration::Boolean"], ["key", "notifications"], ["LIMIT", 1]]
rsync_ui_worker-1  | [ActiveJob] [JobRuns::ExecuteJob] [86647f14-24c5-45b8-9094-a048df096043] [b2c7c404-d1cc-44c0-ab4b-fee3a6100e88] [Pictures] admin/2021/May/IMG_20210516_125744.jpg
rsync_ui_worker-1  | [ActiveJob] [JobRuns::ExecuteJob] [86647f14-24c5-45b8-9094-a048df096043]   TRANSACTION (0.3ms)  BEGIN
rsync_ui_worker-1  | [ActiveJob] [JobRuns::ExecuteJob] [86647f14-24c5-45b8-9094-a048df096043]   Configuration::Boolean Load (0.8ms)  SELECT "configurations".* FROM "configurations" WHERE "configurations"."type" = $1 AND "configurations"."key" = $2 LIMIT $3  [["type", "Configuration::Boolean"], ["key", "streaming"], ["LIMIT", 1]]
```
