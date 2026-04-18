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

Columns:

- [ ] Job ID: a human-readable identifier
- [ ] Schedule ID: a human-readable identifier
- [ ] Repository: name of the repository
- [ ] Trigger: manual or scheduled
- [ ] Status: completed, failed, running
- [ ] Started at: date and time the job started
- [ ] Duration: time elapsed since the start of the job
- [ ] Completed/failed at: date and time the job completed or failed
- [ ] Actions: view log, download log, delete entry (if completed/errored)

**Resource usage**

The resource usage shows the total and used storage, aggregated by repository.

### Servers

Servers are the remote destinations where the files are synchronized to.

A server has the following attributes:

- [x] Name
- [x] Host
- [x] Port
- [x] Username
- [x] Password (optional)
- [x] SSH key (optional)

Either a password or an SSH key must be provided.

- [x] Implement servers page
  - [x] Create server
    - [ ] Test connection: check if the server is reachable with the provided credentials
  - [x] Update server
  - [x] Destroy server

### Repositories

Repositories are the local or remote directories where the files are synchronized from.
They can be located locally, or on a remote server.

A repository has the following attributes:

- [x] Name
- [x] Description (optional)
- [x] Type (local, remote)
- [x] Server (if remote)
- [x] Path
- [x] Read-only (boolean)
- [x] User

- [x] Implement repositories page
  - [x] Create repository
  - [x] Update repository
  - [x] Destroy repository

### Jobs

Jobs are the actual synchronization tasks that are executed by the application.

A job has the following attributes:

- [x] Name
- [x] Description (optional)
- [x] Source repository (foreign key)
- [x] Destination repository (foreign key)
- [x] Schedule: cron expression for scheduling the job (optional)
- [ ] Rsync options
  - [ ] Command-line arguments for rsync
    - [ ] Delete extra files on destination (`--delete`)
    - [ ] Delete extra files on source (`--delete-excluded`)
    - [ ] Preserve permissions (`--perms`)
    - [ ] Preserve ownership (`--owner`)
    - [ ] Preserve group ownership (`--group`)
    - [ ] Preserve timestamps (`--times`)
    - [ ] Preserve ACLs (`--acls`)
    - [ ] Preserve extended attributes (`--xattrs`)
    - [ ] Preserve hard links (`--hard-links`)
    - [ ] Preserve symbolic links (`--symlink-times`)
    - [ ] Preserve device numbers (`--devices`)
    - [ ] Preserve special files (`--specials`)
    - [ ] Preserve inode numbers (`--inodes`)
    - [ ] Preserve extended attributes (`--xattrs`)
    - [ ] Preserve ACLs (`--acls`)
    - [ ] Preserve extended attributes (`--xattrs`)
    - [ ] Preserve hard links (`--hard-links`)
    - [ ] Preserve symbolic links (`--symlink-times`)
    - [ ] Preserve device numbers (`--devices`)
    - [ ] Preserve special files (`--specials`)
  - [ ] Exclude patterns
  - [ ] Include patterns
  - [ ] Run rsync as a different user (or sudo)
  - [ ] Alternate path to rsync binary
- [x] Enabled (boolean)
- [x] User

Validations:

- [x] Source repository must exist
- [x] Destination repository must exist
- [x] Destination repository must be different from source repository
- [x] Destination repository must not be read-only
- [x] Schedule must be valid cron expression

- [x] Implement jobs page
  - [x] Create job
  - [x] Update job
  - [x] Destroy job

## Notifications

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

Tasks:

- [ ] Implement notification services page
  - [ ] Create notification service
    - [ ] Test notification service
  - [ ] Update notification service
  - [ ] Destroy notification service

## Browse repositories

Allow the user to browse the repositories and their contents.
This is useful for debugging and troubleshooting.
For local repositories, the contents can be viewed directly in the browser.
For remote repositories, the server should be mounted as a local directory, and the contents can be viewed in the browser.

## Tasks

- [ ] Implement a dynamic job scheduler (cron daemon)
- [ ] Execution
  - [ ] Add a configuration option (feature category) to enable/disable scheduled jobs: `scheduler`
  - [ ] Implement a service that executes jobs ad-hoc
  - [ ] Add a scheduled job to execute a job if it is due
  - [ ] Track real-time progress of jobs
  - [ ] Capture and save the output of rsync commands
    - [ ] Allow viewing and downloading the log file
  - [ ] Implement sync hooks
    - [ ] Pre-/Post hook: command or script to run before/after the sync starts
    - [ ] Success/error hook: command or script to run when the sync succeeds/fails
- [ ] Real-time visualization on dashboard
  - [ ] Show visualization of repositories (vertices) and schedules (edges) between them
  - [ ] Mark healthy, unhealthy, and ongoing jobs in different colors
  - [ ] Add real-time progress (stretch goal, depends on implementation of the executor)
- [ ] Resource usage
  - [ ] Implement a service that checks a server's resources (CPU, memory, disk space)
  - [ ] Add a configuration option (feature category) to enable/disable resource usage: `resource_usage`
  - [ ] Add a configuration option (feature category) to set the update interval: `resource_usage.interval`, default to 15 minutes
  - [ ] Implement a service that updates the resource usage of a server
  - [ ] Add a scheduled job to update the resource usage of all servers (if enabled)
- [ ] Job creation wizard
  - [ ] Implement a wizard that guides the user through the process of creating a sync job
  - [ ] Step one (source): repository name, description, type (local/remote), server (if remote), path
  - [ ] Step two (destination): repository name, description, type (local/remote), server (if remote), path
  - [ ] Step three: schedule, rsync options, enabled

## Backlog

- [ ] Update branding
- [ ] Implement support for OAuth2 authentication
- [ ] Allow duplicating jobs

## Open questions

- [ ] Should some job options be stored on the repository/server instead of the job? For example: include/exclude patterns, run as different user, path to rsync binary
