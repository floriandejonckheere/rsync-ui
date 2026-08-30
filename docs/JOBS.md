# Scheduled Tasks

All recurring work is driven by a single Solid Queue recurring entry (`config/recurring.yml`): `SchedulerJob` runs **every minute** and fans out to the domain-specific checks below (except SSH config sync, which is triggered reactively). Each per-entity job re-validates its own interval inside `perform` (with a `force:` override), so redundant enqueues from the scheduler are safe. Most of these are also runnable manually and synchronously from the Maintenance UI (`app/tasks/**` via `Tasks::ExecuteService`), which bypasses the interval checks.

| Task | Schedule / trigger | Config gate | Job / service | Scope |
|---|---|---|---|---|
| Sync SSH config | Reactive - `after_commit` on any `Server` create/update/destroy (`app/models/server.rb:59`) | - | `Servers::SyncSSHConfigJob` → `SSHConfigService` | Global - regenerates the whole SSH config file once per commit |
| Terminate stuck jobs | Every minute (first step of `SchedulerJob#perform`) | `terminate_stuck_jobs` (default `true`); grace period `terminate_stuck_jobs.interval` (default 1s) | Inline in `SchedulerJob` → `JobRuns::TerminateStuckService` | Global sweep - one pass over all pending/running/canceling `JobRun`s |
| Schedule jobs | Every minute | `scheduler` (default `true`) | `Jobs::ScheduleJobsService` → enqueues `JobRuns::ExecuteJob` | Per-job - iterates enabled `Job`s with a cron schedule, parsed with Fugit; only due ones are enqueued |
| Connectivity check | Every minute (scheduler check); actual probe cadence `connectivity.interval` (default 5 min) | `connectivity` (default `true`) | `Servers::ConnectionJob` → `ConnectionService` | Per-server - only servers with stale/nil `probed_at` |
| Repo disk size measurement | Every minute (scheduler check); actual cadence `disk_size.interval` (default 240 min) | `disk_size` (default `true`) | `Repositories::DiskSizeJob` → `DiskSizeService` | Per-repository - only repos with stale/nil `disk_size_measured_at` |
| Resource usage measurement | Every minute (scheduler check); actual cadence `resource_usage.interval` (default 15 min) | `resource_usage` (default `true`) | `Servers::ResourceUsageJob` → `ResourceUsageService` | Per-server - only servers with stale/nil `resource_usages.probed_at` |
| Audit purge | Daily at 3am, own `config/recurring.yml` entry (`purge_audits`) | `audits` (default `false`); retention window `audits.retention` (default 7 days) | `Audits::PurgeJob` → `Audits::PurgeService` | Global sweep - deletes all `Audit` records started before the retention threshold |

Other unrelated recurring entries also live in `config/recurring.yml`: `clear_solid_queue_finished_jobs` (every hour at :12) and `SolidCable::TrimJob` (every hour at :30).
