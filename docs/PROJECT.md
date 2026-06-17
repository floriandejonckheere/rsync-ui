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

### Job creation wizard

- [ ] Implement a wizard that guides the user through the process of creating a sync job
- [ ] Step one (source): repository name, description, type (local/remote), server (if remote), path
- [ ] Step two (destination): repository name, description, type (local/remote), server (if remote), path
- [ ] Step three: schedule, rsync options, enabled

### Smaller TODOs

- [ ] Allow user to archive job runs, jobs, repositories, and servers
  - [ ] Extra tab for archived job runs, jobs, repositories, and servers
  - [ ] No connectivity polling for archived servers
  - [ ] No scheduling for archived jobs
- [ ] Make application responsive
- [ ] Make job run immutable and reproducible
  - [ ] Temporary: lock job, repositories, hooks, notifications rows when executing job
  - [x] Save command and options in the database
  - [ ] Save hooks in the database
  - [ ] Save repository in the database
  - [ ] Save notifications in the database
- [ ] Allow retrying jobs, or automatic retry (e.g. with incremental/exponential backoff)
- [ ] Update branding
- [ ] Prevent command injection in "custom rsync command" and "custom rsync options"
- [ ] Hooks::ExecuteService: timeout on command execution
- [ ] Add a local resource usage card
- [ ] Allow custom scripts on startup (e.g. installing packages, https://www.linuxserver.io/blog/2019-09-14-customizing-our-containers)
- [ ] Implement support for OAuth2 authentication
- [ ] Improve auditing: add login, change password, notification sending
- [ ] Do not bind postgres to port 5432, otherwise you can't use git worktrees
- [ ] Audit codebase
- [ ] SSH config: write password/private key only when invoking SSH commands
- [ ] Allow discovery of partitions/disks on the server and measure resource usage per partition/disk
- [ ] Compose: docker compose up creates x-app container
- [ ] Too many `SolidCable::TrimJob` jobs when using ActionCable
- [ ] Only run SyncSSHConfig job periodically, not on startup
- [ ] Throttle/rate limit status updates
- [ ] Make streaming job output fixed height, but scrolling (and anchored to the bottom)
- [ ] Drop `Net::SSH` in favor of plain `ssh`
