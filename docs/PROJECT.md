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

- [ ] Name
- [ ] Type (local, remote)
- [ ] Server (if remote)
- [ ] Path
- [ ] Read-only (boolean)

- [ ] Implement repositories page
  - [ ] Create repository
  - [ ] Update repository
  - [ ] Destroy repository

### Jobs

Jobs are the actual synchronization tasks that are executed by the application.

A job has the following attributes:

- [ ] Name
- [ ] Description (optional)
- [ ] Source repository (foreign key)
- [ ] Destination repository (foreign key)
- [ ] Schedule: cron expression for scheduling the job
- [ ] Rsync options: command-line arguments for rsync
- [ ] Enabled (boolean)

- [ ] Implement jobs page
  - [ ] Create job
  - [ ] Update job
  - [ ] Destroy job

## Tasks

- [ ] Resource probe: check the server's resources (CPU, memory, disk space)
- [ ] Implement a job scheduler (cron daemon)
- [ ] Implement job execution: run the rsync command
  - [ ] Track real-time progress of jobs
  - [ ] Implement job log: view or download the log file

## Backlog

- [ ] Allow sudo to run rsync commands
- [ ] Allow alternate rsync binary (path)
- [ ] Validate SSH keys (no password etc.)
