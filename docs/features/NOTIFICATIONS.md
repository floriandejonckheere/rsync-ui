# Notifications

Notifications can be sent to users when a job starts, completes, or fails.
The user can configure notification services (e.g. email, Slack, ...) to receive these notifications.
Each job can be configured to send notifications on specific events to specific notification services.

## Configurations

- [x] Add `notifications` configuration

## Database model

Notifications have the following attributes:

- [x] Name
- [x] Description (optional)
- [x] URL (Apprise URL), encrypted in the database
- [x] Enabled (boolean)
- [x] User

Notifications have a many-to-many relationship with jobs.
This relationship has the following attributes:

- [x] Job (foreign key)
- [x] Notification service (foreign key)
- [x] Events (on start, on success, on failure)
- [x] Enabled (boolean)

## User interface

- [x] Implement notification services page (visible if `notifications` is enabled)
  - [x] Create notification service
    - [ ] Add a link to the Apprise Wiki: https://appriseit.com/services/
  - [x] Test notification service
  - [x] Update notification service
  - [x] Destroy notification service

- [x] Update the jobs form (visible if `notifications` is enabled)
  - [x] In the left column, add a Notifications card
  - [x] Allow adding notification services to the job, and configuring the events to send notifications for
    - [x] Enabled
    - [x] Events: on start, on success, on failure

## Services

- [x] Implement notification service (only if `notifications` is enabled)
  - [x] Takes as arguments a notification service, a job run, and a user
  - [x] Add hooks on ExecuteJob: on start, on success, on failure: send notifications to configured notification services if enabled
- [x] Add email templates
  - [x] Job started: job name, job ID, source, destination, started at, trigger, triggered by
  - [x] Job completed: job name, job ID, source, destination, started at, completed at, duration, trigger, triggered by
  - [x] Job failed: job name, job ID, source, destination, started at, completed at, duration, trigger, triggered by, error class and message, URL to the job log
