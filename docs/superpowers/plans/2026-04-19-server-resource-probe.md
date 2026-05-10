# Server Resource Probe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Probe each Server over SSH on a configurable interval, store the latest metrics on the `servers` table, and display a "Server health" card on the dashboard with threshold-coloured subcards per server.

**Architecture:** A per-minute `ServerProbeSchedulerJob` (registered via `recurring.yml`) enqueues a `ServerProbeJob` for each Server whose `probed_at` is older than the configured interval. The job invokes `Servers::ProbeService`, which opens a single `Net::SSH` session, runs a combined shell command, parses `/proc` files and `df` output, and updates the Server row. A `ServerHealth` PORO classifies each metric against configurable warn/critical thresholds, and a `Dashboard::ServerHealthComponent` ViewComponent renders the card.

**Tech Stack:** Rails 8.1, Ruby 4.0, PostgreSQL 18, Solid Queue (recurring), `net-ssh`, ViewComponent, Tailwind 4, RSpec + FactoryBot + Timecop + WebMock.

---

## File Map

**Create:**
- `app/services/servers/probe_service.rb`
- `app/jobs/server_probe_job.rb`
- `app/jobs/server_probe_scheduler_job.rb`
- `app/models/server_health.rb` (PORO classifier)
- `app/components/dashboard/server_health_component.rb`
- `app/components/dashboard/server_health_component.html.erb`
- `db/migrate/<timestamp>_add_probe_fields_to_servers.rb`
- `spec/services/servers/probe_service_spec.rb`
- `spec/jobs/server_probe_job_spec.rb`
- `spec/jobs/server_probe_scheduler_job_spec.rb`
- `spec/models/server_health_spec.rb`
- `spec/components/dashboard/server_health_component_spec.rb`

**Modify:**
- `Gemfile` / `Gemfile.lock` — add `net-ssh`
- `config/configurations.yml` — add 8 new keys
- `config/recurring.yml` — register scheduler
- `app/views/dashboard/index.html.erb` — render component
- `app/models/server.rb` — schema annotation only (by annotaterb)
- `spec/factories/servers.rb` — add `:probed` trait (for view tests)
- `config/locales/en.yml` (or new `config/locales/dashboard.en.yml`) — strings

**Docs:**
- `docs/PROJECT.md` — tick off Resource usage items

---

## Conventions For All Tasks

- All Ruby files begin with `# frozen_string_literal: true`.
- Run tests inside docker: `docker compose exec app bundle exec rspec <FILES>`.
- Run rubocop after writing Ruby: `docker compose exec app bundle exec rubocop <FILES> -a`.
- Never run `rails db:migrate` without explicit approval.
- All user-facing strings go through I18n.
- Commit per CLAUDE.md atomic-commit conventions; imperative mood.

---

## Task 1: Add `net-ssh` gem

**Files:**
- Modify: `Gemfile`
- Modify: `Gemfile.lock` (generated)

- [ ] **Step 1: Add gem to Gemfile**

Insert near the other application gems (after `pg`):

```ruby
# SSH client for probing remote servers [https://github.com/net-ssh/net-ssh]
gem "net-ssh", "~> 7.3"
```

- [ ] **Step 2: Install**

Run: `docker compose exec app bundle install`
Expected: `Bundle complete.`, `net-ssh` listed in `Gemfile.lock`.

- [ ] **Step 3: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "Add net-ssh gem"
```

---

## Task 2: Migration — probe columns on `servers`

**Files:**
- Create: `db/migrate/<timestamp>_add_probe_fields_to_servers.rb`

- [ ] **Step 1: Generate migration**

Run: `docker compose exec app bundle exec rails g migration AddProbeFieldsToServers`
Expected: new file under `db/migrate/`.

- [ ] **Step 2: Fill in migration**

```ruby
# frozen_string_literal: true

class AddProbeFieldsToServers < ActiveRecord::Migration[8.1]
  def change
    change_table :servers, bulk: true do |t|
      t.string  :path,           default: "/", null: false
      t.datetime :probed_at
      t.string  :probe_status
      t.text    :probe_error
      t.integer :cpu_count
      t.float   :cpu_usage
      t.bigint  :memory_total
      t.bigint  :memory_used
      t.bigint  :disk_total
      t.bigint  :disk_used
      t.bigint  :uptime_seconds
      t.float   :load_avg_1
      t.float   :load_avg_5
      t.float   :load_avg_15
    end
  end
end
```

- [ ] **Step 3: Ask user for approval, then migrate**

Prompt user explicitly: *"Ready to run `rails db:migrate`?"* Once approved:

Run: `docker compose exec app bundle exec rails db:migrate`
Expected: migration succeeds; `db/schema.rb` updated.

- [ ] **Step 4: Update model annotation**

Run: `docker compose exec app bundle exec annotaterb models`
Expected: `app/models/server.rb` schema comment block shows the new columns.

- [ ] **Step 5: Commit**

```bash
git add db/migrate/ db/schema.rb app/models/server.rb
git commit -m "Add probe fields to servers"
```

---

## Task 3: Configurations

**Files:**
- Modify: `config/configurations.yml`

- [ ] **Step 1: Append new keys**

```yaml
- key: resource_usage
  type: boolean
  category: resource_usage
  default: true
- key: resource_usage.interval
  type: integer
  category: resource_usage
  default: 15
  dependencies:
    - resource_usage
- key: resource_usage.cpu_warning
  type: integer
  category: resource_usage
  default: 75
  dependencies:
    - resource_usage
- key: resource_usage.cpu_critical
  type: integer
  category: resource_usage
  default: 90
  dependencies:
    - resource_usage
- key: resource_usage.memory_warning
  type: integer
  category: resource_usage
  default: 80
  dependencies:
    - resource_usage
- key: resource_usage.memory_critical
  type: integer
  category: resource_usage
  default: 95
  dependencies:
    - resource_usage
- key: resource_usage.disk_warning
  type: integer
  category: resource_usage
  default: 80
  dependencies:
    - resource_usage
- key: resource_usage.disk_critical
  type: integer
  category: resource_usage
  default: 95
  dependencies:
    - resource_usage
```

- [ ] **Step 2: Verify load**

Run: `docker compose exec app bundle exec rails runner 'puts Configuration.configurations.keys.grep(/resource_usage/)'`
Expected: all 8 keys listed.

- [ ] **Step 3: Commit**

```bash
git add config/configurations.yml
git commit -m "Add resource_usage configurations"
```

---

## Task 4: `ServerHealth` classifier

**Files:**
- Create: `app/models/server_health.rb`
- Create: `spec/models/server_health_spec.rb`

- [ ] **Step 1: Write failing spec**

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe ServerHealth do
  before do
    Configuration.set("resource_usage.cpu_warning", 75)
    Configuration.set("resource_usage.cpu_critical", 90)
  end

  describe ".classify" do
    it "returns :ok below warning threshold" do
      expect(described_class.classify(50, metric: :cpu)).to eq(:ok)
    end

    it "returns :warning at or above warning threshold" do
      expect(described_class.classify(80, metric: :cpu)).to eq(:warning)
    end

    it "returns :critical at or above critical threshold" do
      expect(described_class.classify(95, metric: :cpu)).to eq(:critical)
    end

    it "returns :unknown for nil value" do
      expect(described_class.classify(nil, metric: :cpu)).to eq(:unknown)
    end

    it "supports :memory and :disk metrics" do
      Configuration.set("resource_usage.memory_warning", 80)
      Configuration.set("resource_usage.memory_critical", 95)
      expect(described_class.classify(85, metric: :memory)).to eq(:warning)
    end
  end

  describe ".percent" do
    it "returns percentage for used/total" do
      expect(described_class.percent(used: 50, total: 200)).to eq(25.0)
    end

    it "returns nil when total is nil or zero" do
      expect(described_class.percent(used: 10, total: nil)).to be_nil
      expect(described_class.percent(used: 10, total: 0)).to be_nil
    end
  end
end
```

- [ ] **Step 2: Run — expect failure**

Run: `docker compose exec app bundle exec rspec spec/models/server_health_spec.rb`
Expected: FAIL — `uninitialized constant ServerHealth`.

- [ ] **Step 3: Implement**

```ruby
# frozen_string_literal: true

class ServerHealth
  METRICS = %i[cpu memory disk].freeze

  def self.classify(value, metric:)
    return :unknown if value.nil?
    raise ArgumentError, "unknown metric #{metric}" unless METRICS.include?(metric)

    critical = Configuration.get("resource_usage.#{metric}_critical").to_i
    warning  = Configuration.get("resource_usage.#{metric}_warning").to_i

    return :critical if value >= critical
    return :warning  if value >= warning

    :ok
  end

  def self.percent(used:, total:)
    return nil if total.nil? || total.to_f.zero? || used.nil?

    (used.to_f / total.to_f * 100).round(1)
  end
end
```

- [ ] **Step 4: Run — expect pass**

Run: `docker compose exec app bundle exec rspec spec/models/server_health_spec.rb`
Expected: 6 examples, 0 failures.

- [ ] **Step 5: Rubocop + commit**

```bash
docker compose exec app bundle exec rubocop app/models/server_health.rb spec/models/server_health_spec.rb -a
git add app/models/server_health.rb spec/models/server_health_spec.rb
git commit -m "Add ServerHealth classifier"
```

---

## Task 5: `Servers::ProbeService`

**Files:**
- Create: `app/services/servers/probe_service.rb`
- Create: `spec/services/servers/probe_service_spec.rb`
- Create: `spec/support/fixtures/probe_output.txt` — fixture of remote command stdout

- [ ] **Step 1: Write the fixture**

Create `spec/support/fixtures/probe_output.txt`:

```
---CPU---
4
cpu  1000 0 500 8000 0 0 0 0 0 0
cpu  1100 0 550 8350 0 0 0 0 0 0
---MEM---
MemTotal:        8000000 kB
MemFree:         1000000 kB
MemAvailable:    2000000 kB
Buffers:           50000 kB
Cached:           500000 kB
---UPTIME---
123456.78 987654.32
0.42 0.55 0.60 1/234 5678
---DISK---
Filesystem     1B-blocks         Used    Available Capacity Mounted on
/dev/sda1  107374182400  53687091200  53687091200      50% /
```

- [ ] **Step 2: Write failing spec**

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Servers::ProbeService do
  let(:server) { create(:server, :with_password, path: "/") }
  let(:fixture) { Rails.root.join("spec/support/fixtures/probe_output.txt").read }
  let(:ssh_session) { instance_double(Net::SSH::Connection::Session) }

  before do
    allow(Net::SSH).to receive(:start).and_yield(ssh_session)
    allow(ssh_session).to receive(:exec!).and_return(fixture)
  end

  describe "#call" do
    it "updates the server with parsed metrics" do
      described_class.call(server: server)
      server.reload

      expect(server.probe_status).to eq("ok")
      expect(server.probe_error).to be_nil
      expect(server.probed_at).to be_within(5.seconds).of(Time.current)
      expect(server.cpu_count).to eq(4)
      expect(server.cpu_usage).to be_within(0.01).of(30.0)
      expect(server.memory_total).to eq(8_000_000 * 1024)
      expect(server.memory_used).to eq((8_000_000 - 2_000_000) * 1024)
      expect(server.disk_total).to eq(107_374_182_400)
      expect(server.disk_used).to eq(53_687_091_200)
      expect(server.uptime_seconds).to eq(123_456)
      expect(server.load_avg_1).to eq(0.42)
      expect(server.load_avg_5).to eq(0.55)
      expect(server.load_avg_15).to eq(0.60)
    end

    it "quotes the server path into the remote command" do
      server.update!(path: "/var/data space")
      expect(ssh_session).to receive(:exec!).with(a_string_including("'/var/data space'")).and_return(fixture)
      described_class.call(server: server)
    end

    context "when SSH connection fails" do
      before do
        allow(Net::SSH).to receive(:start).and_raise(Net::SSH::ConnectionTimeout, "timed out")
      end

      it "records probe_status=failed and error message" do
        described_class.call(server: server)
        server.reload
        expect(server.probe_status).to eq("failed")
        expect(server.probe_error).to include("timed out")
        expect(server.cpu_usage).to be_nil
      end
    end

    context "when stdout is malformed" do
      before { allow(ssh_session).to receive(:exec!).and_return("garbage") }

      it "records probe_status=failed" do
        described_class.call(server: server)
        server.reload
        expect(server.probe_status).to eq("failed")
      end
    end

    context "when server has an SSH key" do
      let(:server) { create(:server, :with_ssh_key, path: "/") }

      it "passes key_data to Net::SSH.start" do
        expect(Net::SSH).to receive(:start).with(
          server.host,
          server.username,
          hash_including(port: server.port, key_data: [server.ssh_key], non_interactive: true)
        ).and_yield(ssh_session)
        described_class.call(server: server)
      end
    end
  end
end
```

- [ ] **Step 3: Run — expect failure**

Run: `docker compose exec app bundle exec rspec spec/services/servers/probe_service_spec.rb`
Expected: FAIL — `uninitialized constant Servers`.

- [ ] **Step 4: Implement the service**

```ruby
# frozen_string_literal: true

require "net/ssh"
require "shellwords"

module Servers
  class ProbeService < ApplicationService
    CONNECT_TIMEOUT = 10
    EXEC_TIMEOUT = 15
    ERROR_TRUNCATE = 500

    attr_reader :server

    def initialize(server:)
      super()
      @server = server
    end

    def call
      output = run_remote_command
      metrics = Parser.new(output).call
      server.update!(metrics.merge(probe_status: "ok", probe_error: nil, probed_at: Time.current))
    rescue StandardError => e
      server.update!(
        probe_status: "failed",
        probe_error: e.message.to_s[0, ERROR_TRUNCATE],
        probed_at: Time.current,
      )
    end

    private

    def run_remote_command
      output = nil
      Net::SSH.start(server.host, server.username, ssh_options) do |ssh|
        output = ssh.exec!(remote_command)
      end
      output.to_s
    end

    def ssh_options
      opts = {
        port: server.port,
        timeout: CONNECT_TIMEOUT,
        non_interactive: true,
        verify_host_key: :never,
      }
      if server.ssh_key.present?
        opts[:key_data] = [server.ssh_key]
        opts[:keys_only] = true
      elsif server.password.present?
        opts[:password] = server.password
        opts[:auth_methods] = %w[password]
      end
      opts
    end

    def remote_command
      path = Shellwords.escape(server.path.presence || "/")
      <<~SH
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
        df -PB1 #{path}
      SH
    end

    class Parser
      SECTION = /^---(\w+)---$/

      def initialize(output)
        @output = output
      end

      def call
        sections = split_sections
        raise "missing sections" unless %w[CPU MEM UPTIME DISK].all? { |s| sections.key?(s) }

        cpu    = parse_cpu(sections.fetch("CPU"))
        memory = parse_mem(sections.fetch("MEM"))
        uptime = parse_uptime(sections.fetch("UPTIME"))
        disk   = parse_disk(sections.fetch("DISK"))

        cpu.merge(memory).merge(uptime).merge(disk)
      end

      private

      attr_reader :output

      def split_sections
        current = nil
        output.each_line.each_with_object({}) do |line, acc|
          if (m = line.match(SECTION))
            current = m[1]
            acc[current] = []
          elsif current
            acc[current] << line
          end
        end.transform_values(&:join)
      end

      def parse_cpu(text)
        lines = text.lines.map(&:strip).reject(&:empty?)
        cpu_count = Integer(lines.shift)
        samples = lines.first(2).map { |l| l.split[1..].map(&:to_i) }
        raise "cpu sample missing" if samples.size < 2

        idle1 = samples[0][3] + samples[0].fetch(4, 0)
        idle2 = samples[1][3] + samples[1].fetch(4, 0)
        total1 = samples[0].sum
        total2 = samples[1].sum
        total_delta = total2 - total1
        idle_delta  = idle2 - idle1
        usage = total_delta.positive? ? ((1 - idle_delta.to_f / total_delta) * 100).round(2) : 0.0

        { cpu_count:, cpu_usage: usage }
      end

      def parse_mem(text)
        fields = text.lines.each_with_object({}) do |l, h|
          k, v = l.split(":", 2)
          h[k] = v.to_s.strip.split.first.to_i * 1024 if v
        end
        total     = fields.fetch("MemTotal")
        available = fields.fetch("MemAvailable")

        { memory_total: total, memory_used: total - available }
      end

      def parse_uptime(text)
        lines = text.lines.map(&:strip).reject(&:empty?)
        uptime = lines[0].split.first.to_f.to_i
        load_parts = lines[1].split
        {
          uptime_seconds: uptime,
          load_avg_1: load_parts[0].to_f,
          load_avg_5: load_parts[1].to_f,
          load_avg_15: load_parts[2].to_f,
        }
      end

      def parse_disk(text)
        data_line = text.lines.find { |l| l.start_with?("/") || l.match?(/^\S+\s+\d+/) && !l.start_with?("Filesystem") }
        raise "no df output" unless data_line

        parts = data_line.split
        total = parts[1].to_i
        used  = parts[2].to_i

        { disk_total: total, disk_used: used }
      end
    end
  end
end
```

- [ ] **Step 5: Run — expect pass**

Run: `docker compose exec app bundle exec rspec spec/services/servers/probe_service_spec.rb`
Expected: all examples green.

- [ ] **Step 6: Rubocop + commit**

```bash
docker compose exec app bundle exec rubocop app/services/servers/probe_service.rb spec/services/servers/probe_service_spec.rb -a
git add app/services/servers/ spec/services/servers/ spec/support/fixtures/probe_output.txt
git commit -m "Add Servers::ProbeService"
```

---

## Task 6: `ServerProbeJob`

**Files:**
- Create: `app/jobs/server_probe_job.rb`
- Create: `spec/jobs/server_probe_job_spec.rb`

- [ ] **Step 1: Write failing spec**

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe ServerProbeJob do
  let(:server) { create(:server, :with_password) }

  it "invokes Servers::ProbeService with the server" do
    expect(Servers::ProbeService).to receive(:call).with(server: server)
    described_class.perform_now(server)
  end

  it "limits concurrency per server" do
    expect(described_class.new.class).to respond_to(:limits_concurrency).or satisfy { |c| c.instance_method(:perform) }
  end
end
```

- [ ] **Step 2: Run — expect failure**

Run: `docker compose exec app bundle exec rspec spec/jobs/server_probe_job_spec.rb`
Expected: FAIL — `uninitialized constant ServerProbeJob`.

- [ ] **Step 3: Implement**

```ruby
# frozen_string_literal: true

class ServerProbeJob < ApplicationJob
  limits_concurrency to: 1,
                     key: ->(server, **) { server.id },
                     duration: 5.minutes

  def perform(server)
    Servers::ProbeService.call(server: server)
  end
end
```

- [ ] **Step 4: Run — expect pass**

Run: `docker compose exec app bundle exec rspec spec/jobs/server_probe_job_spec.rb`
Expected: green.

- [ ] **Step 5: Rubocop + commit**

```bash
docker compose exec app bundle exec rubocop app/jobs/server_probe_job.rb spec/jobs/server_probe_job_spec.rb -a
git add app/jobs/server_probe_job.rb spec/jobs/server_probe_job_spec.rb
git commit -m "Add ServerProbeJob"
```

---

## Task 7: `ServerProbeSchedulerJob`

**Files:**
- Create: `app/jobs/server_probe_scheduler_job.rb`
- Create: `spec/jobs/server_probe_scheduler_job_spec.rb`
- Modify: `config/recurring.yml`

- [ ] **Step 1: Write failing spec**

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe ServerProbeSchedulerJob do
  let!(:never_probed) { create(:server, :with_password, probed_at: nil) }
  let!(:recent)       { create(:server, :with_password, probed_at: 2.minutes.ago) }
  let!(:stale)        { create(:server, :with_password, probed_at: 30.minutes.ago) }

  before do
    Configuration.set("resource_usage", true)
    Configuration.set("resource_usage.interval", 15)
  end

  it "enqueues a ServerProbeJob for never-probed and stale servers only" do
    expect { described_class.perform_now }
      .to have_enqueued_job(ServerProbeJob).exactly(2).times
    expect(ServerProbeJob).to have_been_enqueued.with(never_probed)
    expect(ServerProbeJob).to have_been_enqueued.with(stale)
    expect(ServerProbeJob).not_to have_been_enqueued.with(recent)
  end

  context "when resource_usage is disabled" do
    before { Configuration.set("resource_usage", false) }

    it "does not enqueue any jobs" do
      expect { described_class.perform_now }.not_to have_enqueued_job(ServerProbeJob)
    end
  end
end
```

Note: the factory currently does not accept `probed_at:` directly — verify that FactoryBot accepts arbitrary attribute overrides for model columns. If not, add a trait in `spec/factories/servers.rb`:

```ruby
trait :probed do
  probed_at { 1.hour.ago }
  probe_status { "ok" }
  cpu_usage { 25.0 }
  cpu_count { 4 }
  memory_total { 8.gigabytes }
  memory_used  { 4.gigabytes }
  disk_total   { 100.gigabytes }
  disk_used    { 30.gigabytes }
  uptime_seconds { 3600 }
  load_avg_1 { 0.5 }; load_avg_5 { 0.6 }; load_avg_15 { 0.7 }
end
```

(Only add the trait if the specs below reference `:probed`.)

- [ ] **Step 2: Run — expect failure**

Run: `docker compose exec app bundle exec rspec spec/jobs/server_probe_scheduler_job_spec.rb`
Expected: FAIL — `uninitialized constant ServerProbeSchedulerJob`.

- [ ] **Step 3: Implement**

```ruby
# frozen_string_literal: true

class ServerProbeSchedulerJob < ApplicationJob
  def perform
    return unless Configuration.get("resource_usage")

    interval = Configuration.get("resource_usage.interval").to_i.minutes
    cutoff   = interval.ago

    Server
      .where("probed_at IS NULL OR probed_at < ?", cutoff)
      .find_each { |server| ServerProbeJob.perform_later(server) }
  end
end
```

- [ ] **Step 4: Register in recurring.yml**

Modify `config/recurring.yml`. Add under `production:` (and also `default:` if there is one, or add a `default:` block):

```yaml
default:
  probe_servers:
    class: ServerProbeSchedulerJob
    schedule: every minute
```

If a `default:` block already exists, merge the `probe_servers` key into it rather than duplicating the header.

- [ ] **Step 5: Run — expect pass**

Run: `docker compose exec app bundle exec rspec spec/jobs/server_probe_scheduler_job_spec.rb`
Expected: green.

- [ ] **Step 6: Rubocop + commit**

```bash
docker compose exec app bundle exec rubocop app/jobs/server_probe_scheduler_job.rb spec/jobs/server_probe_scheduler_job_spec.rb -a
git add app/jobs/server_probe_scheduler_job.rb spec/jobs/server_probe_scheduler_job_spec.rb config/recurring.yml spec/factories/servers.rb
git commit -m "Add ServerProbeSchedulerJob"
```

---

## Task 8: `Dashboard::ServerHealthComponent`

**Files:**
- Create: `app/components/dashboard/server_health_component.rb`
- Create: `app/components/dashboard/server_health_component.html.erb`
- Create: `spec/components/dashboard/server_health_component_spec.rb`
- Modify: `config/locales/en.yml`

- [ ] **Step 1: Add i18n strings**

Under `en:` add (preserving alphabetical order within sections):

```yaml
dashboard:
  server_health:
    title: Server health
    cores: "%{count} cores"
    cpu: CPU
    memory: Memory
    disk: Disk
    uptime: Uptime
    load: Load
    last_probed: "Last probed %{time} ago"
    never_probed: Never probed
    failed: Probe failed
    disabled: Resource usage disabled
    no_servers: No servers configured
    path: "Path: %{path}"
```

Run: `docker compose exec app bundle exec i18n-tasks normalize`
Expected: file reformatted, no new missing keys.

- [ ] **Step 2: Write failing spec**

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dashboard::ServerHealthComponent, type: :component do
  let(:user) { create(:user) }

  before do
    Configuration.set("resource_usage", true)
    Configuration.set("resource_usage.cpu_warning", 75)
    Configuration.set("resource_usage.cpu_critical", 90)
    Configuration.set("resource_usage.memory_warning", 80)
    Configuration.set("resource_usage.memory_critical", 95)
    Configuration.set("resource_usage.disk_warning", 80)
    Configuration.set("resource_usage.disk_critical", 95)
  end

  context "with a healthy server" do
    let(:server) do
      create(:server, :with_password,
        probed_at: 1.minute.ago, probe_status: "ok",
        cpu_usage: 10.0, cpu_count: 4,
        memory_total: 8.gigabytes, memory_used: 2.gigabytes,
        disk_total: 100.gigabytes, disk_used: 10.gigabytes,
        uptime_seconds: 3600,
        load_avg_1: 0.1, load_avg_5: 0.2, load_avg_15: 0.3)
    end

    it "renders a green subcard" do
      render_inline(described_class.new(servers: [server]))
      expect(page).to have_css(".server-health-cpu.bg-green-50")
      expect(page).to have_css(".server-health-memory.bg-green-50")
      expect(page).to have_css(".server-health-disk.bg-green-50")
      expect(page).to have_text(server.name)
    end
  end

  context "with a critical server" do
    let(:server) do
      create(:server, :with_password,
        probed_at: 1.minute.ago, probe_status: "ok",
        cpu_usage: 95.0, cpu_count: 4,
        memory_total: 100, memory_used: 99,
        disk_total: 100, disk_used: 99,
        uptime_seconds: 3600, load_avg_1: 1, load_avg_5: 1, load_avg_15: 1)
    end

    it "renders red subcards" do
      render_inline(described_class.new(servers: [server]))
      expect(page).to have_css(".server-health-cpu.bg-red-50")
      expect(page).to have_css(".server-health-disk.bg-red-50")
    end
  end

  context "with a never-probed server" do
    let(:server) { create(:server, :with_password) }

    it "renders a neutral subcard with 'Never probed'" do
      render_inline(described_class.new(servers: [server]))
      expect(page).to have_text(I18n.t("dashboard.server_health.never_probed"))
    end
  end

  context "with a failed probe" do
    let(:server) do
      create(:server, :with_password, probed_at: 1.minute.ago,
                                      probe_status: "failed", probe_error: "timed out")
    end

    it "shows failure badge" do
      render_inline(described_class.new(servers: [server]))
      expect(page).to have_text(I18n.t("dashboard.server_health.failed"))
      expect(page).to have_text("timed out")
    end
  end

  context "when feature disabled" do
    before { Configuration.set("resource_usage", false) }

    it "renders nothing" do
      render_inline(described_class.new(servers: [create(:server, :with_password)]))
      expect(page.text).to be_blank
    end
  end

  context "with no servers" do
    it "renders nothing" do
      render_inline(described_class.new(servers: []))
      expect(page.text).to be_blank
    end
  end
end
```

- [ ] **Step 3: Run — expect failure**

Run: `docker compose exec app bundle exec rspec spec/components/dashboard/server_health_component_spec.rb`
Expected: FAIL — constant missing.

- [ ] **Step 4: Implement component class**

```ruby
# frozen_string_literal: true

module Dashboard
  class ServerHealthComponent < ViewComponent::Base
    COLOUR_CLASSES = {
      ok:       "bg-green-50 border-green-200 text-green-900",
      warning:  "bg-orange-50 border-orange-200 text-orange-900",
      critical: "bg-red-50 border-red-200 text-red-900",
      unknown:  "bg-gray-50 border-gray-200 text-gray-700",
    }.freeze

    def initialize(servers:)
      @servers = servers
    end

    def render?
      Configuration.get("resource_usage") && @servers.any?
    end

    attr_reader :servers

    def cpu_class(server)
      COLOUR_CLASSES.fetch(ServerHealth.classify(server.cpu_usage, metric: :cpu))
    end

    def memory_class(server)
      COLOUR_CLASSES.fetch(ServerHealth.classify(memory_percent(server), metric: :memory))
    end

    def disk_class(server)
      COLOUR_CLASSES.fetch(ServerHealth.classify(disk_percent(server), metric: :disk))
    end

    def memory_percent(server)
      ServerHealth.percent(used: server.memory_used, total: server.memory_total)
    end

    def disk_percent(server)
      ServerHealth.percent(used: server.disk_used, total: server.disk_total)
    end

    def probed?(server)
      server.probed_at.present?
    end

    def failed?(server)
      server.probe_status == "failed"
    end
  end
end
```

- [ ] **Step 5: Implement component template**

`app/components/dashboard/server_health_component.html.erb`:

```erb
<section class="rounded-lg border p-4">
  <h2 class="text-lg font-semibold mb-3"><%= t("dashboard.server_health.title") %></h2>

  <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
    <% servers.each do |server| %>
      <article class="rounded border p-3">
        <header class="flex justify-between items-baseline mb-2">
          <h3 class="font-medium"><%= server.name %></h3>
          <span class="text-xs text-gray-500"><%= server.host %></span>
        </header>

        <% unless probed?(server) %>
          <p class="text-sm text-gray-500"><%= t("dashboard.server_health.never_probed") %></p>
        <% end %>

        <% if failed?(server) %>
          <p class="text-sm text-red-700">
            <%= t("dashboard.server_health.failed") %>: <%= server.probe_error %>
          </p>
        <% end %>

        <% if probed?(server) && !failed?(server) %>
          <dl class="grid grid-cols-3 gap-2 text-sm">
            <div class="server-health-cpu rounded border p-2 <%= cpu_class(server) %>">
              <dt><%= t("dashboard.server_health.cpu") %></dt>
              <dd><%= number_to_percentage(server.cpu_usage, precision: 1) %></dd>
              <dd class="text-xs"><%= t("dashboard.server_health.cores", count: server.cpu_count) %></dd>
            </div>

            <div class="server-health-memory rounded border p-2 <%= memory_class(server) %>">
              <dt><%= t("dashboard.server_health.memory") %></dt>
              <dd><%= number_to_human_size(server.memory_used) %> / <%= number_to_human_size(server.memory_total) %></dd>
              <dd class="text-xs"><%= number_to_percentage(memory_percent(server), precision: 1) %></dd>
            </div>

            <div class="server-health-disk rounded border p-2 <%= disk_class(server) %>">
              <dt><%= t("dashboard.server_health.disk") %></dt>
              <dd><%= number_to_human_size(server.disk_used) %> / <%= number_to_human_size(server.disk_total) %></dd>
              <dd class="text-xs"><%= number_to_percentage(disk_percent(server), precision: 1) %></dd>
              <dd class="text-xs"><%= t("dashboard.server_health.path", path: server.path) %></dd>
            </div>
          </dl>

          <footer class="mt-2 text-xs text-gray-500">
            <%= t("dashboard.server_health.uptime") %>: <%= distance_of_time_in_words(server.uptime_seconds.seconds) %> ·
            <%= t("dashboard.server_health.load") %>: <%= server.load_avg_1 %> / <%= server.load_avg_5 %> / <%= server.load_avg_15 %> ·
            <%= t("dashboard.server_health.last_probed", time: time_ago_in_words(server.probed_at)) %>
          </footer>
        <% end %>
      </article>
    <% end %>
  </div>
</section>
```

- [ ] **Step 6: Run — expect pass**

Run: `docker compose exec app bundle exec rspec spec/components/dashboard/server_health_component_spec.rb`
Expected: green.

- [ ] **Step 7: Herb format + rubocop + commit**

```bash
docker compose exec app yarn herb:format
docker compose exec app bundle exec rubocop app/components spec/components -a
git add app/components/dashboard spec/components/dashboard config/locales/en.yml
git commit -m "Add Dashboard::ServerHealthComponent"
```

---

## Task 9: Wire component into dashboard

**Files:**
- Modify: `app/views/dashboard/index.html.erb`
- Modify: `app/controllers/dashboard_controller.rb`

- [ ] **Step 1: Expose servers from controller**

Replace the controller body with:

```ruby
# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize! :dashboard
    @servers = current_user.servers.order(:name)
  end
end
```

- [ ] **Step 2: Render component in view**

Append to `app/views/dashboard/index.html.erb`:

```erb
<%= render(Dashboard::ServerHealthComponent.new(servers: @servers)) %>
```

- [ ] **Step 3: Add request spec smoke test**

`spec/requests/dashboard_spec.rb` (create or extend). If the file exists already, add a single example; otherwise:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it "renders successfully with no servers" do
    get dashboard_path
    expect(response).to have_http_status(:ok)
  end

  it "renders the server health card when a probed server exists" do
    create(:server, :with_password,
           user: user, probed_at: 1.minute.ago, probe_status: "ok",
           cpu_usage: 10, cpu_count: 2,
           memory_total: 100, memory_used: 10,
           disk_total: 100, disk_used: 10,
           uptime_seconds: 10, load_avg_1: 0, load_avg_5: 0, load_avg_15: 0)
    get dashboard_path
    expect(response.body).to include(I18n.t("dashboard.server_health.title"))
  end
end
```

Note: confirm `current_user.servers` works by checking `User has_many :servers` — if the association is missing, add it in `app/models/user.rb` (`has_many :servers, dependent: :destroy`) as part of this task.

- [ ] **Step 4: Run — expect pass**

Run: `docker compose exec app bundle exec rspec spec/requests/dashboard_spec.rb`
Expected: green.

- [ ] **Step 5: Herb + rubocop + commit**

```bash
docker compose exec app yarn herb:format
docker compose exec app bundle exec rubocop app/controllers/dashboard_controller.rb -a
git add app/controllers/dashboard_controller.rb app/views/dashboard/index.html.erb spec/requests/dashboard_spec.rb app/models/user.rb
git commit -m "Render server health card on dashboard"
```

---

## Task 10: Full regression + project docs

- [ ] **Step 1: Run full suite**

Run: `docker compose exec app bundle exec rspec`
Expected: all green.

- [ ] **Step 2: Run rubocop + herb over changed files**

Run: `docker compose exec app bundle exec rubocop && docker compose exec app yarn herb:format`
Expected: no violations.

- [ ] **Step 3: Tick off `docs/PROJECT.md`**

Under "### Resource usage" mark these items `[x]`:
- Implement a service that checks a server's resources (CPU, memory, disk space)
- Add a configuration option (feature category) to enable or disable resource usage: `resource_usage`
- Add a configuration option (feature category) to set the update interval: `resource_usage.interval`, default `15 minutes`
- Implement a service that updates the resource usage of a server
- Add a scheduled job to update the resource usage of all servers when enabled

- [ ] **Step 4: Commit**

```bash
git add docs/PROJECT.md
git commit -m "Tick off resource usage in PROJECT.md"
```

---

## Spec Coverage Check

| Spec section | Implementing task(s) |
| --- | --- |
| Probe service (single SSH exec) | Task 5 |
| Per-server job + concurrency | Task 6 |
| Scheduler (per-minute, interval-gated, feature-flagged) | Task 7 |
| Schema (probe columns + `path`) | Task 2 |
| Configurations (8 keys under `resource_usage`) | Task 3 |
| `ServerHealth` classifier | Task 4 |
| Dashboard card + subcards + colour thresholds | Tasks 8, 9 |
| i18n strings | Task 8 |
| `net-ssh` dependency | Task 1 |
| Failure handling (SSH errors + parse errors) | Task 5 |
| Full regression + project docs | Task 10 |
