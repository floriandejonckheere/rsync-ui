# Server Resource Probe — Design

Date: 2026-04-19
Branch: `feature/resource-probe`

## Goal

Probe each enabled remote server over SSH at a configurable interval to collect
CPU, memory, disk, uptime, and load-average metrics. Store the latest probe
result on the `servers` table. Surface the results on the dashboard as a
"Server health" card with a coloured subcard per server.

## Non-Goals

- Historical time-series of probe results (single latest snapshot only).
- Alerting / notifications on threshold breach.
- Probing local repositories (only Servers are probed).
- Multi-filesystem disk reporting (one `path` per server).

## Architecture

### Components

| Component | Responsibility |
| --- | --- |
| `Servers::ProbeService` | Opens one SSH session, runs the combined shell command, parses output, updates the `Server` record. |
| `ServerProbeJob` | ActiveJob wrapper around the service; rescues exceptions into `probe_status = "failed"` and `probe_error`. |
| `ServerProbeSchedulerJob` | Runs every minute via `recurring.yml`; short-circuits if `resource_usage` is disabled; enqueues `ServerProbeJob` for each due server. |
| `ServerHealth` (helper/PORO) | Classifies a metric percentage as `:ok` / `:warning` / `:critical` using threshold configurations. |
| `Dashboard::ServerHealthComponent` | ViewComponent that renders the "Server health" card and a subcard per server. |

### Data flow

```
recurring.yml → ServerProbeSchedulerJob
                 ├─ read `resource_usage` + `resource_usage.interval`
                 └─ for each Server where probed_at is stale:
                      ServerProbeJob.perform_later(server)
                        └─ Servers::ProbeService.call(server:)
                             ├─ Net::SSH.start(...) { |ssh| ssh.exec!(remote_cmd) }
                             ├─ parse stdout
                             └─ server.update!(cpu_usage:, memory_*, disk_*, …, probed_at:, probe_status: "ok")

Dashboard#index → renders Dashboard::ServerHealthComponent.new(servers: current_user.servers)
                    └─ per server: reads last metrics + ServerHealth.classify → colour class
```

## Schema

Add to `servers`:

| Column | Type | Default | Notes |
| --- | --- | --- | --- |
| `path` | `string` | `"/"` | Filesystem to measure with `df`. |
| `probed_at` | `datetime` | | Last successful OR failed probe. |
| `probe_status` | `string` | | `"ok"` or `"failed"`. |
| `probe_error` | `text` | | Message from last failure. |
| `cpu_count` | `integer` | | From `nproc`. |
| `cpu_usage` | `float` | | 0.0–100.0, derived from two `/proc/stat` samples. |
| `memory_total` | `bigint` | | Bytes. |
| `memory_used` | `bigint` | | Bytes. `MemTotal − MemAvailable`. |
| `disk_total` | `bigint` | | Bytes (from `df -PB1`). |
| `disk_used` | `bigint` | | Bytes. |
| `uptime_seconds` | `bigint` | | First field of `/proc/uptime`. |
| `load_avg_1` | `float` | | |
| `load_avg_5` | `float` | | |
| `load_avg_15` | `float` | | |

All columns nullable (no probe may have run yet). One migration per logical
change (per CLAUDE.md convention): a single migration adding all probe columns
is acceptable since they are one cohesive change.

## Remote Command

Single `ssh.exec!` string, with `<path>` substituted from `server.path`:

```sh
set -e
echo "---CPU---"
nproc
grep '^cpu ' /proc/stat
sleep 1
grep '^cpu ' /proc/stat
echo "---MEM---"
cat /proc/meminfo
echo "---UPTIME---"
cat /proc/uptime
cat /proc/loadavg
echo "---DISK---"
df -PB1 "<path>"
```

Parsing is done section-by-section in the service. CPU utilization:

```
idle_delta  = (idle2 + iowait2) − (idle1 + iowait1)
total_delta = sum(cpu2) − sum(cpu1)
cpu_usage   = 100.0 * (1 − idle_delta / total_delta)
```

`path` is shell-quoted before interpolation.

## Configurations

All under category `resource_usage`. Added to `config/configurations.yml`.

| Key | Type | Default | Purpose |
| --- | --- | --- | --- |
| `resource_usage` | boolean | `true` | Master enable for the feature. |
| `resource_usage.interval` | integer | `15` | Minutes between probes per server. Depends on `resource_usage`. |
| `resource_usage.cpu_warning` | integer | `75` | Orange threshold, percent. |
| `resource_usage.cpu_critical` | integer | `90` | Red threshold, percent. |
| `resource_usage.memory_warning` | integer | `80` | |
| `resource_usage.memory_critical` | integer | `95` | |
| `resource_usage.disk_warning` | integer | `80` | |
| `resource_usage.disk_critical` | integer | `95` | |

Threshold configs depend on `resource_usage`.

## Scheduling

`ServerProbeSchedulerJob` is added to `recurring.yml`:

```yaml
probe_servers:
  class: ServerProbeSchedulerJob
  schedule: every minute
```

The scheduler job:

1. Returns early unless `Configuration.get("resource_usage")` is true.
2. Reads `interval = Configuration.get("resource_usage.interval").to_i.minutes`.
3. `Server.where("probed_at IS NULL OR probed_at < ?", interval.ago).find_each { |s| ServerProbeJob.perform_later(s) }`.

This intentionally avoids a static recurring schedule so changing the interval
config takes effect within a minute without requiring a scheduler restart.

## Failure handling

`Servers::ProbeService` rescues `Net::SSH::Exception`, `Errno::ETIMEDOUT`,
`SocketError`, `Timeout::Error`, and parse errors. On failure it updates
`probed_at = Time.current`, `probe_status = "failed"`, `probe_error = e.message`
(truncated to 500 chars) and does NOT modify metric columns. A connection
timeout of 10 seconds is applied to `Net::SSH.start`.

Authentication uses the same credentials already modelled on `Server`
(password or `ssh_key`).

## Dashboard

The existing `app/views/dashboard/index.html.erb` is extended to render the
"Server health" card. The component is located at
`app/components/dashboard/server_health_component.rb` (+ `.html.erb`).

Subcard per server shows:

- Server name + host
- CPU: `usage %` with `cpu_count` cores
- Memory: `used / total` (formatted via `number_to_human_size`) + percent
- Disk: `used / total` (at `path`) + percent
- Uptime: humanized via `distance_of_time_in_words`
- Load: `1 / 5 / 15`
- Last probed: relative time; if `probe_status == "failed"`, show error badge
  and omit metric colouring (render neutral grey).

Colours: CSS classes `bg-green-50 border-green-200`, `bg-orange-...`,
`bg-red-...`, applied per metric by `ServerHealth.classify(value, metric)`.

If `resource_usage` is disabled or the user has no servers, the entire card is
hidden.

## Tests (RSpec)

- `spec/services/servers/probe_service_spec.rb` — stub `Net::SSH.start` to
  yield a fake session that returns fixture stdout; assert parsed columns and
  happy-path update. Separate cases for SSH failure, command timeout, and
  malformed output.
- `spec/jobs/server_probe_job_spec.rb` — asserts service is called and
  exceptions flow into `probe_status = "failed"`.
- `spec/jobs/server_probe_scheduler_job_spec.rb` — uses Timecop and factory
  servers with varying `probed_at` to assert only due servers are enqueued;
  asserts feature flag short-circuit.
- `spec/components/dashboard/server_health_component_spec.rb` — rendering
  tests for each colour band, failed probe, and never-probed server.
- `spec/models/server_spec.rb` — new columns + `path` default.
- `spec/models/configuration_spec.rb` — existing; ensure new YAML loads.

## Dependencies

Add `net-ssh` to the `Gemfile` in its own commit.

## Commit plan (high level)

1. Add `net-ssh` gem.
2. Migration: add probe columns + `path` to `servers`.
3. Add `resource_usage.*` configurations.
4. Implement `Servers::ProbeService`.
5. Implement `ServerProbeJob`.
6. Implement `ServerProbeSchedulerJob` + `recurring.yml` entry.
7. Implement `ServerHealth` classifier.
8. Implement `Dashboard::ServerHealthComponent` and wire into
   `dashboard/index.html.erb`.
9. i18n strings + `i18n-tasks normalize`.
10. Update `docs/PROJECT.md` checklist.
