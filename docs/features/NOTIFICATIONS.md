# Notifications

Notifications can be sent to users when a job starts, completes, or fails.
The user can configure notification services (e.g. email, Slack, ...) to receive these notifications.
Each job can be configured to send notifications on specific events to specific notification services.

## Configurations

- [ ] Add `notifications` configuration

## Database model

Notifications have the following attributes:

- [ ] Name
- [ ] Description (optional)
- [ ] URL (Apprise URL), encrypted in the database
- [ ] Enabled (boolean)
- [ ] User

Notifications have a many-to-many relationship with jobs.
This relationship has the following attributes:

- [ ] Job (foreign key)
- [ ] Notification service (foreign key)
- [ ] Events (on start, on success, on failure)
- [ ] Enabled (boolean)

## User interface

- [ ] Implement notification services page (visible if `notifications` is enabled)
  - [ ] Create notification service
    - [ ] Add a link to the Apprise Wiki: https://appriseit.com/services/
  - [ ] Test notification service
  - [ ] Update notification service
  - [ ] Destroy notification service

- [ ] Update the jobs form (visible if `notifications` is enabled)
  - [ ] In the left column, add a Notifications card
  - [ ] Allow adding notification services to the job, and configuring the events to send notifications for
    - [ ] Enabled
    - [ ] Events: on start, on success, on failure

## Services

- [ ] Implement notification service (only if `notifications` is enabled)
  - [ ] Takes as arguments a notification service, a job run, and a user
  - [ ] Add hooks on ExecuteJob: on start, on success, on failure: send notifications to configured notification services if enabled
- [ ] Add email templates
  - [ ] Job started: job name, job ID, source, destination, started at, trigger, triggered by
  - [ ] Job completed: job name, job ID, source, destination, started at, completed at, duration, trigger, triggered by
  - [ ] Job failed: job name, job ID, source, destination, started at, completed at, duration, trigger, triggered by, error class and message, URL to the job log
