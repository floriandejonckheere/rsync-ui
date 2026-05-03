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

### Servers

Servers are the remote destinations where the files are synchronized to.

- [ ] Deploy SSH key to the server
  - [ ] Generate new SSH key pair
  - [ ] Upload SSH key to the server (using password)

### Execution and scheduling

- [ ] Implement sync hooks
  - [ ] Pre-/post-hook: command or script to run before or after the sync starts (source and destination)
  - [ ] Success/error hook: command or script to run when the sync succeeds or fails

### Browse repositories

Allow the user to browse the repositories and their contents.
This is useful for debugging and troubleshooting.
For local repositories, the contents can be viewed directly in the browser.
For remote repositories, the server should be mounted as a local directory, and the contents can be viewed in the browser.

- [ ] Implement repository browsing
  - [ ] Local repositories
  - [ ] Remote repositories

### Visualization and monitoring

- [ ] Show a real-time visualization of repositories (vertices) and schedules (edges) on the dashboard
- [ ] Mark healthy, unhealthy, and ongoing jobs in different colors
- [ ] Add real-time progress to the visualization (ActionCable)

### Job creation wizard

- [ ] Implement a wizard that guides the user through the process of creating a sync job
- [ ] Step one (source): repository name, description, type (local/remote), server (if remote), path
- [ ] Step two (destination): repository name, description, type (local/remote), server (if remote), path
- [ ] Step three: schedule, rsync options, enabled

### Smaller TODOs

- [ ] Make application responsive
- [ ] Update branding
- [ ] Prevent command injection in "custom rsync command" and "custom rsync options"
- [ ] Move I18n keys from `config/locales/en.yml` to `config/locales/en/module.yml`
- [ ] Capture number of bytes and number of files transferred on the job run
  - [ ] Add to job run details
  - [ ] Add to notification email
- [ ] Add a local resource usage card
- [ ] Allow streaming logs
- [ ] Add duplicate job button
- [ ] Implement support for OAuth2 authentication
- [ ] Add filter functionality
  - [ ] Servers
  - [ ] Repositories
  - [ ] Jobs
- [ ] Do not bind postgres to port 5432, otherwise you can't use git worktrees
- [ ] Add max/min to configurations
- [ ] Audit codebase
