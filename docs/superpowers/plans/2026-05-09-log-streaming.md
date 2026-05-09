# Log Streaming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement real-time rsync log streaming to the browser via ActionCable, with a dedicated `/job_runs/:id/logs` page that appends log lines and replaces the status line as they arrive.

**Architecture:** `Jobs::ExecuteService` broadcasts each output line directly via `ActionCable.server.broadcast`. A `JobRunLogsChannel` authorizes subscriptions via `JobRunPolicy#logs?` and streams from a per-job-run channel. A Stimulus controller on the logs page subscribes and updates the DOM. The existing `logs` action (blob download) is first renamed to `output` in a separate commit.

**Tech Stack:** Ruby on Rails 8, ActionCable (Solid Cable), ActionPolicy, Hotwire Turbo-Rails (`subscribeTo`), Stimulus, Tailwind CSS, RSpec

---

## File Map

**Create:**
- `app/channels/application_cable/connection.rb` — authenticates WebSocket via Devise warden session
- `app/channels/application_cable/channel.rb` — base channel class
- `app/channels/job_run_logs_channel.rb` — authorizes and streams per-job-run log messages
- `app/views/job_runs/logs.html.erb` — live streaming page
- `app/javascript/controllers/job_run_logs_controller.js` — Stimulus WebSocket subscriber
- `spec/channels/job_run_logs_channel_spec.rb` — channel subscription specs

**Modify:**
- `config/routes.rb` — rename `logs` → `output`, add `logs`
- `config/configurations.yml` — add `streaming` feature flag
- `config/locales/configurations/en.yml` — add `streaming` description
- `config/locales/job_runs/en.yml` — add `logs` page strings and `stream_logs` action label
- `app/controllers/job_runs_controller.rb` — rename `logs` → `output`, add `logs` action
- `app/policies/job_run_policy.rb` — add `output?` policy action
- `app/services/jobs/execute_service.rb` — broadcast each line to ActionCable
- `app/views/job_runs/_job_run.html.erb` — add stream button for running jobs; `logs_` → `output_` path helper
- `app/views/job_runs/show.html.erb` — `logs_job_run_path` → `output_job_run_path`
- `app/javascript/controllers/index.js` — register `job-run-logs` Stimulus controller
- `spec/requests/job_runs_request_spec.rb` — rename existing logs block, add new logs specs
- `spec/services/jobs/execute_service_spec.rb` — add broadcasting specs

---

### Task 1: Rename `logs` → `output`

Pure rename — no new functionality. Keep this as its own commit.

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/job_runs_controller.rb`
- Modify: `app/policies/job_run_policy.rb`
- Modify: `app/views/job_runs/_job_run.html.erb`
- Modify: `app/views/job_runs/show.html.erb`
- Modify: `spec/requests/job_runs_request_spec.rb`

- [ ] **Step 1: Update routes**

In `config/routes.rb`, change `get :logs` to `get :output` in the `job_runs` member block:

```ruby
resources :job_runs, only: [:index, :show, :create, :destroy] do
  member do
    patch :cancel
    get :output
  end
end
```

Then regenerate the route annotation:

```bash
docker compose exec app bundle exec annotaterb routes
```

- [ ] **Step 2: Update controller**

In `app/controllers/job_runs_controller.rb`:
1. Change `before_action :set_job_run, only: [:show, :logs, :destroy, :cancel]` → `only: [:show, :output, :destroy, :cancel]`
2. Rename the `logs` method to `output`

```ruby
before_action :set_job_run, only: [:show, :output, :destroy, :cancel]

def output
  authorize! @job_run

  return head :not_found unless @job_run.output.attached?

  filename = [
    "job",
    @job_run.sequence,
    @job_run.job.name.titleize,
    @job_run.started_at&.iso8601,
  ].compact.join("-").concat(".log")

  redirect_to rails_blob_path(@job_run.output, disposition: "attachment; filename=\"#{filename}\""), allow_other_host: true
end
```

- [ ] **Step 3: Add `output?` policy action**

In `app/policies/job_run_policy.rb`, add after `logs?`:

```ruby
def output?
  user.admin? || record.user == user
end
```

- [ ] **Step 4: Update path helpers in views**

In `app/views/job_runs/_job_run.html.erb`: change `logs_job_run_path(job_run)` → `output_job_run_path(job_run)`.

In `app/views/job_runs/show.html.erb`: change `logs_job_run_path(@job_run)` → `output_job_run_path(@job_run)`.

- [ ] **Step 5: Update request spec**

In `spec/requests/job_runs_request_spec.rb`, rename `describe "GET /job_runs/:id/logs"` to `describe "GET /job_runs/:id/output"` and replace all `logs_job_run_path` with `output_job_run_path` inside that block.

- [ ] **Step 6: Run tests**

```bash
docker compose exec app bundle exec rspec spec/requests/job_runs_request_spec.rb spec/policies/job_run_policy_spec.rb -f documentation
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/job_runs_controller.rb app/policies/job_run_policy.rb app/views/job_runs/_job_run.html.erb app/views/job_runs/show.html.erb spec/requests/job_runs_request_spec.rb
git commit -m "Rename logs action to output"
```

---

### Task 2: Add `streaming` configuration key

**Files:**
- Modify: `config/configurations.yml`
- Modify: `config/locales/configurations/en.yml`

- [ ] **Step 1: Add key to configurations.yml**

In `config/configurations.yml`, add after the `hooks` entry:

```yaml
- key: streaming
  type: boolean
  category: features
  default: true
```

- [ ] **Step 2: Add locale string**

In `config/locales/configurations/en.yml`, under `en.configurations.keys`, add after `hooks`:

```yaml
streaming:
  description: Enable or disable real-time log streaming via ActionCable
```

- [ ] **Step 3: Normalize i18n**

```bash
docker compose exec app bundle exec i18n-tasks normalize
```

- [ ] **Step 4: Commit**

```bash
git add config/configurations.yml config/locales/configurations/en.yml
git commit -m "Add streaming configuration key"
```

---

### Task 3: Add ActionCable connection, base channel, and JobRunLogsChannel

TDD: write the channel spec first, then implement.

**Files:**
- Create: `app/channels/application_cable/connection.rb`
- Create: `app/channels/application_cable/channel.rb`
- Create: `app/channels/job_run_logs_channel.rb`
- Create: `spec/channels/job_run_logs_channel_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/channels/job_run_logs_channel_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe JobRunLogsChannel, type: :channel do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:job_run) { create(:job_run, :running, user:) }

  before { stub_connection current_user: user }

  describe "#subscribed" do
    context "when authorized" do
      it "confirms subscription and streams from the job run channel" do
        subscribe job_run_id: job_run.id

        expect(subscription).to be_confirmed
        expect(streams).to include("job_run_logs_#{job_run.id}")
      end
    end

    context "when job run is not found" do
      it "rejects the subscription" do
        subscribe job_run_id: "00000000-0000-0000-0000-000000000000"

        expect(subscription).to be_rejected
      end
    end

    context "when user is not authorized" do
      before { stub_connection current_user: other_user }

      it "rejects the subscription" do
        subscribe job_run_id: job_run.id

        expect(subscription).to be_rejected
      end
    end

    context "when streaming feature is disabled" do
      with_configuration "streaming" => false

      it "rejects the subscription" do
        subscribe job_run_id: job_run.id

        expect(subscription).to be_rejected
      end
    end
  end
end
```

- [ ] **Step 2: Run to verify it fails**

```bash
docker compose exec app bundle exec rspec spec/channels/job_run_logs_channel_spec.rb -f documentation
```

Expected: FAIL — `JobRunLogsChannel` uninitialized constant.

- [ ] **Step 3: Create ActionCable base files**

Create `app/channels/application_cable/connection.rb`:

```ruby
# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      if (user = env["warden"].user(:user))
        user
      else
        reject_unauthorized_connection
      end
    end
  end
end
```

Create `app/channels/application_cable/channel.rb`:

```ruby
# frozen_string_literal: true

module ApplicationCable
  class Channel < ActionCable::Channel::Base
  end
end
```

- [ ] **Step 4: Create JobRunLogsChannel**

Create `app/channels/job_run_logs_channel.rb`:

```ruby
# frozen_string_literal: true

class JobRunLogsChannel < ApplicationCable::Channel
  def subscribed
    job_run = JobRun.find_by(id: params[:job_run_id])

    return reject unless job_run
    return reject unless Configuration.get("streaming")
    return reject unless JobRunPolicy.new(job_run, user: current_user).logs?

    stream_from "job_run_logs_#{params[:job_run_id]}"
  end
end
```

- [ ] **Step 5: Run spec to verify it passes**

```bash
docker compose exec app bundle exec rspec spec/channels/job_run_logs_channel_spec.rb -f documentation
```

Expected: all 4 examples pass.

- [ ] **Step 6: Commit**

```bash
git add app/channels/ spec/channels/job_run_logs_channel_spec.rb
git commit -m "Add JobRunLogsChannel with ActionCable connection"
```

---

### Task 4: Add broadcasting to Jobs::ExecuteService

TDD: write spec for broadcasting, then implement.

**Files:**
- Modify: `app/services/jobs/execute_service.rb`
- Modify: `spec/services/jobs/execute_service_spec.rb`

- [ ] **Step 1: Write failing specs**

In `spec/services/jobs/execute_service_spec.rb`, add a `describe "streaming"` block inside `describe "#call"`, after the existing `describe "hooks"` block:

```ruby
describe "streaming" do
  with_configuration "streaming" => true

  let(:log_line) { "file.txt\n" }

  before do
    allow(ActionCable.server).to receive(:broadcast)
    allow(rsync_execute_service)
      .to receive(:call)
      .and_yield(log_line)
      .and_return(rsync_result)
  end

  it "broadcasts log lines to the job run channel" do
    service.call

    expect(ActionCable.server)
      .to have_received(:broadcast)
      .with("job_run_logs_#{job_run.id}", { type: "log", content: log_line })
  end

  context "when line matches status pattern and opt_progress2 is enabled" do
    let(:status_line) { "  1,234,567  75%  10.00MB/s  0:00:10\r" }
    let(:options) { { opt_progress: true, opt_progress2: true } }

    before do
      allow(rsync_execute_service)
        .to receive(:call)
        .and_yield(status_line)
        .and_return(rsync_result)
    end

    it "broadcasts the line as a status message" do
      service.call

      expect(ActionCable.server)
        .to have_received(:broadcast)
        .with("job_run_logs_#{job_run.id}", { type: "status", content: status_line })
    end
  end

  context "when streaming is disabled" do
    with_configuration "streaming" => false

    it "does not broadcast" do
      service.call

      expect(ActionCable.server).not_to have_received(:broadcast)
    end
  end
end
```

- [ ] **Step 2: Run to verify they fail**

```bash
docker compose exec app bundle exec rspec spec/services/jobs/execute_service_spec.rb -e "streaming" -f documentation
```

Expected: FAIL — `broadcast` not received.

- [ ] **Step 3: Implement broadcasting in Jobs::ExecuteService**

In `app/services/jobs/execute_service.rb`, replace the `Rsync::ExecuteService` call block with:

```ruby
result = Rsync::ExecuteService.new(command, job_run).call do |line|
  bytes_copied, progress = parse_status(line) if job.opt_progress || job.opt_progress2

  is_status = bytes_copied && progress

  if Configuration.get("streaming")
    ActionCable.server.broadcast(
      "job_run_logs_#{job_run.id}",
      { type: is_status ? "status" : "log", content: line },
    )
  end

  if job.opt_progress2 && is_status
    job_run.update!(
      bytes_copied:,
      progress:,
    )

    last_status_line = line
  else
    file.write(line)
  end
end
```

- [ ] **Step 4: Run the full service spec**

```bash
docker compose exec app bundle exec rspec spec/services/jobs/execute_service_spec.rb -f documentation
```

Expected: all examples pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/jobs/execute_service.rb spec/services/jobs/execute_service_spec.rb
git commit -m "Broadcast rsync output lines to ActionCable channel"
```

---

### Task 5: Add `logs` controller action and request spec

TDD: write the request spec first, then implement.

**Files:**
- Modify: `app/controllers/job_runs_controller.rb`
- Modify: `spec/requests/job_runs_request_spec.rb`

- [ ] **Step 1: Add streaming `logs` route**

In `config/routes.rb`, add `get :logs` to the `job_runs` member block:

```ruby
resources :job_runs, only: [:index, :show, :create, :destroy] do
  member do
    patch :cancel
    get :output
    get :logs
  end
end
```

Regenerate the annotation:

```bash
docker compose exec app bundle exec annotaterb routes
```

- [ ] **Step 2: Write failing request specs**

In `spec/requests/job_runs_request_spec.rb`, add a new `describe "GET /job_runs/:id/logs"` block (after the `output` block):

```ruby
describe "GET /job_runs/:id/logs" do
  let(:job_run) { create(:job_run, :running, user:) }

  context "when authenticated" do
    before { sign_in user, scope: :user }

    it "renders the logs page" do
      get logs_job_run_path(job_run)

      expect(response).to have_http_status(:ok)
    end

    context "when streaming feature is disabled" do
      with_configuration "streaming" => false

      it "returns not found" do
        get logs_job_run_path(job_run)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  context "when job run belongs to another user" do
    let(:job_run) { create(:job_run, :running, user: other_user) }

    before { sign_in user, scope: :user }

    it "returns forbidden" do
      get logs_job_run_path(job_run)

      expect(response).to have_http_status(:forbidden)
    end
  end

  context "when not authenticated" do
    it "redirects to sign in" do
      get logs_job_run_path(job_run)

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
```

- [ ] **Step 3: Run to verify they fail**

```bash
docker compose exec app bundle exec rspec spec/requests/job_runs_request_spec.rb -e "GET /job_runs/:id/logs" -f documentation
```

Expected: FAIL — action not defined / template missing.

- [ ] **Step 4: Implement the controller action**

In `app/controllers/job_runs_controller.rb`:

1. Add `:logs` to `before_action :set_job_run`:

```ruby
before_action :set_job_run, only: [:show, :output, :logs, :destroy, :cancel]
```

2. Add `logs` action after `output`:

```ruby
def logs
  authorize! @job_run

  return head :not_found unless Configuration.get("streaming")
end
```

- [ ] **Step 5: Run full request spec**

```bash
docker compose exec app bundle exec rspec spec/requests/job_runs_request_spec.rb -f documentation
```

Expected: the 3 new specs fail with "missing template" (view not yet created) — that's expected at this stage; the 404 and 403 specs pass.

- [ ] **Step 6: Commit (partial — view comes next)**

```bash
git add config/routes.rb app/controllers/job_runs_controller.rb spec/requests/job_runs_request_spec.rb
git commit -m "Add streaming logs controller action and request specs"
```

---

### Task 6: Add logs view, I18n strings, and stream button

**Files:**
- Create: `app/views/job_runs/logs.html.erb`
- Modify: `config/locales/job_runs/en.yml`
- Modify: `app/views/job_runs/_job_run.html.erb`

- [ ] **Step 1: Add I18n strings**

In `config/locales/job_runs/en.yml`, under `en.job_runs`:

1. Add `stream_logs` to the existing `actions` section:
```yaml
actions:
  stream_logs: Stream logs
```

2. Add a new `logs` section:
```yaml
logs:
  completed_at: Completed at
  output: Output
  started_at: Started at
  subtitle: 'Streaming logs for job: %{job}'
  title: 'Job run #%{sequence}'
```

Then normalize:
```bash
docker compose exec app bundle exec i18n-tasks normalize
```

- [ ] **Step 2: Create the logs view**

Create `app/views/job_runs/logs.html.erb`:

```erb
<% content_for :back do %>
  <%= render "shared/menu/back", path: job_runs_path %>
<% end %>

<% content_for :title do %>
  <%= I18n.t("job_runs.logs.title", sequence: @job_run.sequence) %>
<% end %>

<% content_for :subtitle do %>
  <%= I18n.t("job_runs.logs.subtitle", job: @job_run.job.name) %>
<% end %>

<div class="card p-0 mb-6">
  <div class="flex flex-wrap items-center justify-between gap-4 px-6 py-4">
    <div
      class="
        flex items-center gap-2 font-medium text-gray-900 dark:text-gray-100
        truncate
      "
    >
      <%= lucide_icon "play", class: "h-4 w-4 flex-shrink-0 text-gray-500 dark:text-gray-400" %>
      <span class="truncate"><%= @job_run.job.name %></span>
    </div>

    <div
      class="
        flex flex-wrap items-center gap-6 text-sm text-gray-500 dark:text-gray-400
      "
    >
      <div class="<%= job_run_status_classes(@job_run.status) %>">
        <% if @job_run.running? && @job_run.progress %>
          <%= I18n.t("job_runs.status.running_progress", progress: @job_run.progress) %>
        <% else %>
          <%= I18n.t("job_runs.status.#{@job_run.status}") %>
        <% end %>
      </div>

      <div>
        <%= I18n.t("job_runs.logs.started_at") %>:
        <%= @job_run.started_at ? relative_time_tag(@job_run.started_at) : "—" %>
      </div>

      <div>
        <%= I18n.t("job_runs.logs.completed_at") %>:
        <%= @job_run.completed_at ? relative_time_tag(@job_run.completed_at) : "—" %>
      </div>
    </div>
  </div>
</div>

<div
  class="card p-0"
  data-controller="job-run-logs"
  data-job-run-logs-job-run-id-value="<%= @job_run.id %>"
>
  <div
    class="
      flex items-center gap-2 px-6 py-4 border-b border-gray-100
      dark:border-gray-700 text-sm text-gray-500 dark:text-gray-400
    "
  >
    <%= lucide_icon "file-text", class: "h-4 w-4" %>
    <span><%= I18n.t("job_runs.logs.output") %></span>
  </div>

  <pre
    class="
      p-6 text-xs font-mono text-gray-800 dark:text-gray-200 whitespace-pre-wrap
    "
    data-job-run-logs-target="log"
  ></pre>

  <% if @job_run.job.opt_progress || @job_run.job.opt_progress2 %>
    <div
      class="px-6 pb-4 text-xs font-mono text-blue-600 dark:text-blue-400"
      data-job-run-logs-target="status"
    ></div>
  <% end %>
</div>
```

- [ ] **Step 3: Add stream button to job run partial**

In `app/views/job_runs/_job_run.html.erb`, inside the `elsif job_run.pending? || job_run.running?` branch, add the stream button before the cancel button:

```erb
<% elsif job_run.pending? || job_run.running? %>
  <% if job_run.running? && Configuration.get("streaming") %>
    <%= link_to logs_job_run_path(job_run),
                class: "btn-icon-outline btn-icon-md",
                data: { tooltip: I18n.t("job_runs.actions.stream_logs"), turbo_frame: "_top" } do %>
      <%= lucide_icon "activity", class: "h-4 w-4" %>
    <% end %>
  <% end %>

  <%= link_to cancel_job_run_path(job_run),
              class: "btn-icon-outline btn-icon-md",
              data: {
                tooltip: I18n.t("job_runs.actions.cancel"),
                "turbo-method": :patch,
                "turbo-confirm": I18n.t("job_runs.actions.cancel_confirm"),
                "turbo-confirm-title": I18n.t("job_runs.actions.cancel_confirm_title"),
              } do %>
    <%= lucide_icon "x", class: "h-4 w-4" %>
  <% end %>
<% end %>
```

- [ ] **Step 4: Format ERB**

```bash
docker compose exec app yarn herb:format
```

- [ ] **Step 5: Run the full request spec**

```bash
docker compose exec app bundle exec rspec spec/requests/job_runs_request_spec.rb -f documentation
```

Expected: all examples pass.

- [ ] **Step 6: Commit**

```bash
git add app/views/job_runs/logs.html.erb app/views/job_runs/_job_run.html.erb config/locales/job_runs/en.yml
git commit -m "Add streaming logs page and stream button"
```

---

### Task 7: Add Stimulus controller and register it

**Files:**
- Create: `app/javascript/controllers/job_run_logs_controller.js`
- Modify: `app/javascript/controllers/index.js`

- [ ] **Step 1: Create the Stimulus controller**

Create `app/javascript/controllers/job_run_logs_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"
import { subscribeTo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["log", "status"]
  static values = { jobRunId: String }

  async connect() {
    this.subscription = await subscribeTo(
      { channel: "JobRunLogsChannel", job_run_id: this.jobRunIdValue },
      { received: (data) => this.#handleMessage(data) },
    )
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }

  #handleMessage(data) {
    if (data.type === "log") {
      this.logTarget.textContent += data.content
    } else if (data.type === "status" && this.hasStatusTarget) {
      this.statusTarget.textContent = data.content
    }
  }
}
```

- [ ] **Step 2: Register the controller in index.js**

In `app/javascript/controllers/index.js`, add (maintaining alphabetical order):

```javascript
import JobRunLogsController from "./job_run_logs_controller"
application.register("job-run-logs", JobRunLogsController)
```

Place it between the existing `GaugeController` and `PieChartController` registrations.

- [ ] **Step 3: Build JavaScript to verify no compile errors**

```bash
docker compose exec app yarn build:js
```

Expected: exits 0, no errors.

- [ ] **Step 4: Run the full test suite for touched files**

```bash
docker compose exec app bundle exec rspec spec/requests/job_runs_request_spec.rb spec/channels/job_run_logs_channel_spec.rb spec/services/jobs/execute_service_spec.rb spec/policies/job_run_policy_spec.rb -f documentation
```

Expected: all examples pass.

- [ ] **Step 5: Commit**

```bash
git add app/javascript/controllers/job_run_logs_controller.js app/javascript/controllers/index.js
git commit -m "Add job run logs Stimulus controller"
```

---

## Self-Review Checklist

- [x] `streaming` config key added (Task 2) before it's used in channel (Task 3), service (Task 4), and controller (Task 5)
- [x] `output?` policy action added so renamed `output` action authorizes correctly
- [x] `logs?` policy action kept for the new streaming `logs` action and channel
- [x] Status line broadcast only fires when `bytes_copied && progress` are non-nil (i.e. line matched `STATUS_PATTERN` and a progress option was enabled)
- [x] `hasStatusTarget` guard in Stimulus controller handles jobs with neither progress option enabled
- [x] Channel spec uses `with_configuration "streaming" => false` for feature-disabled case
- [x] Service spec stubs `ActionCable.server` before calling `service.call`
- [x] All locale strings under `job_runs.logs.*` and `job_runs.actions.stream_logs` added before the view is created
- [x] Route annotation regenerated after routes change (Tasks 1 and 5)
- [x] ERB formatting run after view changes (Task 6)
