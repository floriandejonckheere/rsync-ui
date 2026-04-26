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

**Resource usage**

The resource usage shows the total and used storage, aggregated by repository.

### Servers

Servers are the remote destinations where the files are synchronized to.

- [ ] Test connection during server setup and editing
- [ ] Deploy SSH key to the server
  - [ ] Generate new SSH key pair
  - [ ] Upload SSH key to the server (using password)

### Jobs

Jobs are the actual synchronization tasks that are executed by the application.

- [ ] Include/Exclude patterns

### Execution and scheduling

- [x] Add a configuration option (feature category) to enable or disable scheduled jobs: `scheduler`
- [x] Track real-time progress of jobs

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

- [ ] Implement repository browsing
  - [ ] Local repositories
  - [ ] Remote repositories

### Visualization and monitoring

- [ ] Show a real-time visualization of repositories (vertices) and schedules (edges) on the dashboard
- [ ] Mark healthy, unhealthy, and ongoing jobs in different colors
- [ ] Add real-time progress to the visualization

### Job creation wizard

- [ ] Implement a wizard that guides the user through the process of creating a sync job
- [ ] Step one (source): repository name, description, type (local/remote), server (if remote), path
- [ ] Step two (destination): repository name, description, type (local/remote), server (if remote), path
- [ ] Step three: schedule, rsync options, enabled

### Future enhancements

- [ ] Update branding
- [ ] Implement support for OAuth2 authentication
- [ ] Allow duplicating jobs
- [x] Add search functionality
  - [ ] Job runs page
- [ ] Add filter functionality
  - [ ] Servers
  - [ ] Repositories
  - [ ] Jobs

### Technical TODOs

- [ ] Do not bind to port 5432, otherwise you can't use git worktrees
- [ ] Use SolidQueue's [dynamic scheduling](https://github.com/rails/solid_queue#scheduling-and-unscheduling-recurring-tasks-dynamically) instead of the Servers::ResourceUsageSchedulerJob
- [ ] Add a `with_configuration` helper
- [ ] Make menubar responsive
- [ ] Tooltips are not always on top, they clip on table edges
- [ ] Prevent command injection in "custom rsync command" and "custom rsync options"

## Open questions

- [ ] Should some job options be stored on the repository/server instead of the job? For example: include/exclude patterns, run as different user, path to rsync binary
