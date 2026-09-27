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

### Repository browser

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

### Presets

In the job form, add a dropdown with "presets" that, when selected, pre-select a certain set of options that are best for a specific use case.

#### Borg preset

Essential flags:

- `--archive`: preserves permissions, ownership, timestamps, symlinks, which is critical for Borg's integrity
- `--delete-after`: removes files on destination that aren't in source, maintaining consistency
- `--whole-file`: avoids the delta-transfer algorithm; Borg data is already compressed, so byte-level syncing is inefficient
- `--numeric-ids`: preserves numeric user/group IDs in case they differ between systems

Recommended flags:

- `-H`/`--hard-links` (hard links): preserves hard links within the Borg repo
- `--sparse`: efficiently handles sparse files
- `-x`/`--one-file-system`: don't cross filesystem boundaries accidentally
- `-P`: equivalent to `--partial --progress`: resume interrupted transfers and show progress

Avoid:

- `-z`/`--compress`: Borg data is already compressed; this wastes CPU
- `--ignore-existing`: you want to overwrite files if they've changed

Hooks:

- `[ ! -e "$repo/lock.exclusive" ] && [ ! -e "$repo/lock.shared" ]`: check for presence of exclusive/shared locks

### Responsiveness

Make the application responsive.
All pages should be accessible and work in a handheld device.

- [ ] Make sidebar collapsible
- [ ] Make sign in page responsive
- [ ] Make application template responsive
- [ ] Make application pages responsive
  - [ ] Dashboard
  - [ ] Activity log
  - [ ] Servers
  - [ ] Repositories
  - [ ] Jobs
    - [ ] Special attention to horizontally scrollable bulk edit page
  - [ ] Notifications
  - [ ] Audits
  - [ ] Configuration
  - [ ] Account
 
### Smaller TODOs

#### High priority

- [ ] Allow hooks to access to the source/destination repository
  - [ ] `{source_repository}`, `{destination_repository}` path variables
  - [ ] Ability to ssh into source/destination server
- [ ] Make job run immutable and reproducible
  - [ ] Temporary: lock job, repositories, hooks, notifications rows when executing job
  - [ ] Save hooks in the database
  - [ ] Save repository in the database
  - [ ] Save notifications in the database
- [ ] (Local) repository path: allow browsing/selecting existing directories
- [x] Remote repositories (source/destination): add option to ping server before starting job, configure cancel/abort if not reachable

#### Medium priority

- [ ] Implement support for OAuth2 authentication
- [ ] Prevent command injection in "custom rsync command" and "custom rsync options"
- [ ] Implement backoff for servers: after N failed retries, disable connectivity/resource usage

#### Low priority

- [ ] Allow retrying jobs, or automatic retry (e.g. with incremental/exponential backoff)
- [ ] Allow custom scripts on startup (e.g. installing packages, https://www.linuxserver.io/blog/2019-09-14-customizing-our-containers)
- [ ] Improve auditing: add login, change password, notification sending
- [x] SSH config: write password/private key only when invoking SSH commands
- [ ] Allow discovery of partitions/disks on the server and measure resource usage per partition/disk
- [ ] Repository disk size: count files and directories as well
