# Rsync UI

Rsync UI is a web application that lets you create, schedule, and execute file synchronization jobs with just a few clicks, powered by [rsync](https://github.com/RsyncProject/rsync).

## Highlights

- Dashboard for job health, activity, schedules, and storage
- Synchronization jobs for local and remote destinations
- Fully customizable command-line arguments
- Real-time synchronization progress
- Automation through scheduled jobs
- Push notifications
- Remote server management with SSH key deployment and storage visibility

## Features

### Dashboard

The dashboard provides a comprehensive overview of your synchronization jobs, including health, activity, schedules, and storage.

Visible elements include:

- Overall status (healthy, degraded): healthy if all jobs are running successfully, degraded if any job is failing
- Number of repositories: local and remote
- Number of jobs: completed in the past 24 hours, and scheduled in the next 24 hours
- Last run and its status (success/fail)
- Cumulated total and used storage

**Status**

- [ ] Implement status: healthy, degraded
- [ ] Implement repository overview
- [ ] Implement job overview
- [ ] Implement last run overview
- [ ] Implement storage overview

**Activity log**

The activity log shows an overview of the jobs executed in reverse chronological order.
The table name is `job_runs`.

Job runs have the following attributes:

- [ ] Job (foreign key)
- [ ] User (foreign key)
- [ ] Sequence: auto-incremented sequence number
- [ ] Trigger: manual or scheduled
- [ ] Status: pending (default), running, completed, failed, canceled
- [ ] Started at: date and time the job started
- [ ] Duration: time elapsed since the start of the job
- [ ] Completed/failed at: date and time the job completed or failed
- [ ] Actions: view log, download log, delete entry (if completed/errored)

- [ ] Implement activity log page (below dashboard link)
  - [ ] Implement activity log table with the following columns:
    - [ ] Job ID (sequence number)
    - [ ] Repository (name)
    - [ ] Trigger
    - [ ] Status
    - [ ] Started at
    - [ ] Duration (if completed), otherwise running time (since started)
    - [ ] Completed/failed at
    - [ ] Action buttons
      - [ ] View log (out of scope for now)
      - [ ] Download log (out of scope for now)
      - [ ] Delete entry (if completed/failed/cancelled), otherwise cancel (if pending/running)

**Resource usage**

The resource usage shows the total and used storage, aggregated by repository.

### Servers

Servers are the remote destinations where the files are synchronized to.

- [ ] Test connection during server setup and editing

### Jobs

Jobs are the actual synchronization tasks that are executed by the application.

- [ ] Include/Exclude patterns
- [ ] Render human-readable cron expression

### Execution and scheduling

- [ ] Implement a dynamic job scheduler (cron daemon)
- [ ] Add a configuration option (feature category) to enable or disable scheduled jobs: `scheduler`
- [ ] Implement a service that executes jobs ad hoc
  - [ ] Track real-time progress of jobs
  - [ ] Capture and save the output of rsync commands
  - [ ] Allow viewing and downloading the log file
- [ ] Add a scheduled job to execute a job if it is due

- [ ] Implement sync hooks
  - [ ] Pre-/post-hook: command or script to run before or after the sync starts
  - [ ] Success/error hook: command or script to run when the sync succeeds or fails

### Notifications

Notifications can be sent to users when a job starts, completes, or fails.
The user can configure notification services (e.g. email, Slack, ...) to receive these notifications.
Each job can be configured to send notifications on specific events to specific notification targets.

Notifications have the following attributes:

- [ ] Name
- [ ] Description (optional)
- [ ] URL (Apprise URL)
- [ ] Enabled (boolean)
- [ ] User

Notifications have a many-to-many relationship with jobs.
This relationship has the following attributes:

- [ ] Job (foreign key)
- [ ] Notification target (foreign key)
- [ ] Events (on start, on success, on failure)
- [ ] Enabled (boolean)

- [ ] Implement notification services page
  - [ ] Create notification service
  - [ ] Test notification service
  - [ ] Update notification service
  - [ ] Destroy notification service

### Browse repositories

Allow the user to browse the repositories and their contents.
This is useful for debugging and troubleshooting.
For local repositories, the contents can be viewed directly in the browser.
For remote repositories, the server should be mounted as a local directory, and the contents can be viewed in the browser.

### Visualization and monitoring

- [ ] Show a real-time visualization of repositories (vertices) and schedules (edges) on the dashboard
- [ ] Mark healthy, unhealthy, and ongoing jobs in different colors
- [ ] Add real-time progress to the visualization

### Resource usage

- [ ] Implement a service that checks a server's resources (CPU, memory, disk space)
- [ ] Add a configuration option (feature category) to enable or disable resource usage: `resource_usage`
- [ ] Add a configuration option (feature category) to set the update interval: `resource_usage.interval`, default `15 minutes`
- [ ] Implement a service that updates the resource usage of a server
- [ ] Add a scheduled job to update the resource usage of all servers when enabled

### Job creation wizard

- [ ] Implement a wizard that guides the user through the process of creating a sync job
- [ ] Step one (source): repository name, description, type (local/remote), server (if remote), path
- [ ] Step two (destination): repository name, description, type (local/remote), server (if remote), path
- [ ] Step three: schedule, rsync options, enabled

### Future enhancements

- [ ] Update branding
- [ ] Implement support for OAuth2 authentication
- [ ] Allow duplicating jobs

## Open questions

- [ ] Should some job options be stored on the repository/server instead of the job? For example: include/exclude patterns, run as different user, path to rsync binary
