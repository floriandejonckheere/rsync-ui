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

### Repository size

- [ ] Add repository size column to table and views
- [ ] Add scheduled job to update repository size
  - [ ] Local: use `du`
  - [ ] Remote: use `du` unless the server is a storage box

### Smaller TODOs

- [ ] Allow user to archive job runs, jobs, repositories, and servers
  - [ ] Extra tab for archived job runs, jobs, repositories, and servers
  - [ ] No connectivity polling for archived servers
  - [ ] No scheduling for archived jobs
- [ ] Make application responsive
- [ ] Make job run immutable: save command and options in the database
- [ ] Update branding
- [ ] Prevent command injection in "custom rsync command" and "custom rsync options"
- [ ] Add a local resource usage card
- [ ] Allow custom scripts on startup (e.g. installing packages, https://www.linuxserver.io/blog/2019-09-14-customizing-our-containers)
- [ ] Implement support for OAuth2 authentication
- [ ] Do not bind postgres to port 5432, otherwise you can't use git worktrees
- [ ] Audit codebase
- [ ] SSH config: write password/private key only when invoking SSH commands
- [ ] Allow discovery of partitions/disks on the server and measure resource usage per partition/disk
- [ ] Compose: docker compose up creates x-app container
- [ ] Too many `SolidCable::TrimJob` jobs when using ActionCable
- [ ] Only run SyncSSHConfig job periodically, not on startup
- [ ] Make streaming job output fixed height, but scrolling (and anchored to the bottom)
- [ ] Concurrent SyncSSHConfig jobs
  rsync_ui_worker-1  | [ActiveJob] [Servers::SyncSSHConfigJob] [1a386230-aef4-4526-b891-6c243c0dc905] Performing Servers::SyncSSHConfigJob (Job ID: 1a386230-aef4-4526-b891-6c243c0dc905) from SolidQueue(default) enqueued at 2026-05-21T19:58:45.866266737Z
  rsync_ui_worker-1  | SolidQueue-1.4.0 Started Scheduler (226.1ms)  pid: 29, hostname: "eb9133693bd7", process_id: 44, name: "scheduler-f43d4c1adc9b05f00348", recurring_schedule: ["clear_solid_queue_finished_jobs", "scheduler"]
  rsync_ui_worker-1  | [ActiveJob] [Servers::SyncSSHConfigJob] [1a386230-aef4-4526-b891-6c243c0dc905] Performed Servers::SyncSSHConfigJob (Job ID: 1a386230-aef4-4526-b891-6c243c0dc905) from SolidQueue(default) in 145.55ms
  rsync_ui_worker-1  | [ActiveJob] [Servers::SyncSSHConfigJob] [2c58323a-efed-4669-89b9-3500f15aeb31] Performing Servers::SyncSSHConfigJob (Job ID: 2c58323a-efed-4669-89b9-3500f15aeb31) from SolidQueue(default) enqueued at 2026-05-21T19:58:49.282777115Z
  rsync_ui_worker-1  | [ActiveJob] [Servers::SyncSSHConfigJob] [34bde2a7-a0fb-4859-be9a-e3bd00db86ef] Performing Servers::SyncSSHConfigJob (Job ID: 34bde2a7-a0fb-4859-be9a-e3bd00db86ef) from SolidQueue(default) enqueued at 2026-05-21T19:58:47.573273356Z
  rsync_ui_worker-1  | SolidQueue-1.4.0 Claim jobs (73.4ms)  process_id: 43, job_ids: [28968], claimed_job_ids: [28968], size: 1
  rsync_ui_worker-1  | [ActiveJob] [Servers::SyncSSHConfigJob] [2c58323a-efed-4669-89b9-3500f15aeb31] Performed Servers::SyncSSHConfigJob (Job ID: 2c58323a-efed-4669-89b9-3500f15aeb31) from SolidQueue(default) in 67.32ms
  rsync_ui_worker-1  | [ActiveJob] [Servers::SyncSSHConfigJob] [34bde2a7-a0fb-4859-be9a-e3bd00db86ef] Error performing Servers::SyncSSHConfigJob (Job ID: 34bde2a7-a0fb-4859-be9a-e3bd00db86ef) from SolidQueue(default) in 24.09ms: Errno::ENOENT (No such file or directory @ rb_file_s_rename - (/app/.ssh/config.tmp, /app/.ssh/config)):
  rsync_ui_worker-1  | app/services/servers/ssh_config_service.rb:97:in 'File.rename'
  rsync_ui_worker-1  | app/services/servers/ssh_config_service.rb:97:in 'Servers::SSHConfigService#call'
  rsync_ui_worker-1  | app/services/application_service.rb:5:in 'ApplicationService.call'
  rsync_ui_worker-1  | app/jobs/servers/sync_ssh_config_job.rb:6:in 'Servers::SyncSSHConfigJob#perform'
  rsync_ui_worker-1  | [ActiveJob] [Servers::SyncSSHConfigJob] [55e52c2d-9607-46fd-93ca-752237800c72] Performing Servers::SyncSSHConfigJob (Job ID: 55e52c2d-9607-46fd-93ca-752237800c72) from SolidQueue(default) enqueued at 2026-05-21T19:58:50.546955919Z
  rsync_ui_worker-1  | SolidQueue-1.4.0 Error in thread (0.0ms)  error: "Errno::ENOENT No such file or directory @ rb_file_s_rename - (/app/.ssh/config.tmp, /app/.ssh/config)"
  rsync_ui_worker-1  | [ActiveJob] [Servers::SyncSSHConfigJob] [55e52c2d-9607-46fd-93ca-752237800c72] Performed Servers::SyncSSHConfigJob (Job ID: 55e52c2d-9607-46fd-93ca-752237800c72) from SolidQueue(default) in 103.8ms
  rsync_ui_worker-1  | SolidQueue-1.4.0 Claim jobs (43.8ms)  process_id: 43, job_ids: [28969], claimed_job_ids: [28969], size: 1
  rsync_ui_worker-1  | [ActiveJob] [Servers::SyncSSHConfigJob] [f8e7711a-3932-4968-8741-edddeffa9347] Performing Servers::SyncSSHConfigJob (Job ID: f8e7711a-3932-4968-8741-edddeffa9347) from SolidQueue(default) enqueued at 2026-05-21T19:58:50.955973151Z
  rsync_ui_worker-1  | [ActiveJob] [Servers::SyncSSHConfigJob] [f8e7711a-3932-4968-8741-edddeffa9347] Performed Servers::SyncSSHConfigJob (Job ID: f8e7711a-3932-4968-8741-edddeffa9347) from SolidQueue(default) in 46.08ms
  rsync_ui_worker-1  | SolidQueue-1.4.0 Claim jobs (96.0ms)  process_id: 43, job_ids: [28970], claimed_job_ids: [28970], size: 1
  rsync_ui_worker-1  | [ActiveJob] [Servers::SyncSSHConfigJob] [f904c032-e8c1-472e-acd0-92f308c8ca90] Performing Servers::SyncSSHConfigJob (Job ID: f904c032-e8c1-472e-acd0-92f308c8ca90) from SolidQueue(default) enqueued at 2026-05-21T19:58:53.502571527Z
  rsync_ui_worker-1  | [ActiveJob] [Servers::SyncSSHConfigJob] [f904c032-e8c1-472e-acd0-92f308c8ca90] Performed Servers::SyncSSHConfigJob (Job ID: f904c032-e8c1-472e-acd0-92f308c8ca90) from SolidQueue(default) in 35.01ms
