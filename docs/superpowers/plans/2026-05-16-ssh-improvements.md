# SSH Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add host-key fingerprint verification to all SSH connections and a managed `~/.ssh/config` + key-file setup so `rsync` can authenticate (password or key) without user interaction.

**Architecture:** Section 1 adds a `fingerprint` column to `servers`, a `HostKeyVerifier` inside `SSHService`, a new `FingerprintService`, and a form button to fetch and store the fingerprint. Section 2 adds `SshConfigService` (writes `~/.ssh/config` and key/password files atomically) driven by a `SyncSshConfigJob` enqueued on every server commit, plus updated `Rsync::CommandService` to use the managed SSH config.

**Tech Stack:** Rails 8 / Ruby 4, Net::SSH, Hotwire Turbo Streams, Stimulus, RSpec/FactoryBot, Alpine Linux / Docker, sshpass

---

## File Map

### Section 1 — Authenticity

| Action | Path |
|--------|------|
| Create | `db/migrate/TIMESTAMP_add_fingerprint_to_servers.rb` |
| Modify | `app/models/server.rb` — add fingerprint validation |
| Modify | `spec/factories/servers.rb` — add default fingerprint |
| Modify | `spec/support/net_ssh.rb` — extend `stub_ssh` with fingerprint support |
| Modify | `app/services/servers/ssh_service.rb` — add `HostKeyVerifier`, swap `:never` |
| Modify | `spec/services/servers/ssh_service_spec.rb` — fingerprint verification tests |
| Modify | `spec/services/servers/connection_service_spec.rb` — fingerprint integration tests |
| Create | `app/services/servers/fingerprint_service.rb` |
| Create | `spec/services/servers/fingerprint_service_spec.rb` |
| Modify | `config/routes.rb` — add `fingerprint` member route |
| Modify | `app/controllers/servers_controller.rb` — add `fingerprint` action |
| Modify | `app/policies/server_policy.rb` — add `fingerprint?` |
| Modify | `app/views/servers/_form.html.erb` — fingerprint field + fetch button |
| Create | `app/javascript/controllers/server_fingerprint_controller.js` |
| Modify | `config/locales/servers/en.yml` — new keys |

### Section 2 — Authentication

| Action | Path |
|--------|------|
| Create | `app/services/servers/ssh_config_service.rb` |
| Create | `spec/services/servers/ssh_config_service_spec.rb` |
| Create | `app/jobs/servers/sync_ssh_config_job.rb` |
| Create | `spec/jobs/servers/sync_ssh_config_job_spec.rb` |
| Modify | `app/models/server.rb` — add `after_commit` callbacks |
| Create | `config/initializers/ssh_config.rb` |
| Modify | `app/services/rsync/command_service.rb` — SSH config flags + UUID paths |
| Modify | `spec/services/rsync/command_service_spec.rb` — update remote-repo tests |
| Modify | `Dockerfile` — add sshpass |
| Modify | `docs/COMMANDS.md` — document sshpass prerequisite |

---

## Section 1 — Authenticity

---

### Task 1: Add fingerprint migration

**Files:**
- Create: `db/migrate/TIMESTAMP_add_fingerprint_to_servers.rb`

- [ ] **Step 1: Generate and inspect migration**

```bash
docker compose exec app bundle exec rails generate migration AddFingerprintToServers fingerprint:string
```

Open the generated file and confirm it looks like:

```ruby
# frozen_string_literal: true

class AddFingerprintToServers < ActiveRecord::Migration[8.0]
  def change
    add_column :servers, :fingerprint, :string
  end
end
```

- [ ] **Step 2: Run migration** (confirm before running, as required by project conventions)

```bash
docker compose exec app bundle exec rails db:migrate
```

- [ ] **Step 3: Update model annotations**

```bash
docker compose exec app bundle exec annotaterb models
```

Confirm `# fingerprint :string` appears in the `# == Schema Information` block at the bottom of `app/models/server.rb`.

- [ ] **Step 4: Commit**

```bash
git add db/migrate/ app/models/server.rb db/schema.rb
git commit -m "Add fingerprint column to servers"
```

---

### Task 2: `verify_host_key` configuration

**Files:**
- Modify: `config/configurations.yml`
- Modify: `config/locales/configurations/en.yml`

- [ ] **Step 1: Add the configuration key**

In `config/configurations.yml`, add a new top-level entry in the `connectivity` category (no dependencies):

```yaml
- key: verify_host_key
  type: boolean
  category: connectivity
  default: true
```

- [ ] **Step 2: Add I18n description**

In `config/locales/configurations/en.yml`, add a new top-level key under `configurations.keys`:

```yaml
      verify_host_key:
        description: Verify server host key fingerprint on every SSH connection (recommended)
```

- [ ] **Step 3: Commit**

```bash
git add config/configurations.yml config/locales/configurations/en.yml
git commit -m "Add verify_host_key configuration"
```

---

### Task 4: Server model fingerprint validation (TDD)

**Files:**
- Modify: `app/models/server.rb`
- Modify: `spec/models/server_spec.rb`
- Modify: `config/locales/servers/en.yml`

- [ ] **Step 1: Write failing tests**

Add to `spec/models/server_spec.rb`:

```ruby
describe "validations" do
  describe "fingerprint" do
    it "is valid when blank" do
      server = build(:server, fingerprint: nil)
      expect(server).to be_valid
    end

    it "is valid with a proper SHA256 fingerprint" do
      server = build(:server, fingerprint: "SHA256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
      expect(server).to be_valid
    end

    it "is invalid with a bad format" do
      server = build(:server, fingerprint: "notafingerprint")
      expect(server).not_to be_valid
      expect(server.errors[:fingerprint]).to be_present
    end

    it "is invalid with an MD5-style fingerprint" do
      server = build(:server, fingerprint: "ab:cd:ef:01:23:45:67:89:ab:cd:ef:01:23:45:67:89")
      expect(server).not_to be_valid
    end
  end
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
docker compose exec app bundle exec rspec spec/models/server_spec.rb -e "fingerprint" --format documentation
```

Expected: FAIL — `is invalid with a bad format` and others fail because there is no validation yet.

- [ ] **Step 3: Add validation to the model**

In `app/models/server.rb`, add after the existing `validate` lines:

```ruby
validates :fingerprint,
          format: { with: /\ASHA256:[A-Za-z0-9+\/=]{43}\z/ },
          allow_blank: true
```

- [ ] **Step 4: Add I18n error message**

In `config/locales/servers/en.yml`, under `activerecord.errors.models.server.attributes`, add:

```yaml
            fingerprint:
              invalid: is not a valid SHA256 fingerprint
```

- [ ] **Step 5: Run tests to confirm they pass**

```bash
docker compose exec app bundle exec rspec spec/models/server_spec.rb -e "fingerprint" --format documentation
```

Expected: all fingerprint validation tests PASS.

- [ ] **Step 6: Commit**

```bash
git add app/models/server.rb config/locales/servers/en.yml spec/models/server_spec.rb
git commit -m "Add fingerprint validation to Server model"
```

---

### Task 5: Add default fingerprint to server factory + update test stub

**Files:**
- Modify: `spec/factories/servers.rb`
- Modify: `spec/support/net_ssh.rb`

This task prepares the test infrastructure for fingerprint-aware SSH connections. The default factory fingerprint must match `stub_ssh`'s default so existing tests keep passing.

- [ ] **Step 1: Add default fingerprint to factory**

In `spec/factories/servers.rb`, add `fingerprint` to the base factory:

```ruby
factory :server do
  user

  name { FFaker::Internet.domain_word.capitalize }
  host { FFaker::Internet.domain_name }
  port { 22 }
  username { FFaker::Internet.user_name }
  password { FFaker::Internet.password }
  fingerprint { "SHA256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" }

  operating_system { "linux" }
  # ... existing traits unchanged ...
end
```

- [ ] **Step 2: Rewrite `stub_ssh` to call the verifier**

Replace the entire body of `spec/support/net_ssh.rb`:

```ruby
# frozen_string_literal: true

module NetSSHHelpers
  DEFAULT_FINGERPRINT = "SHA256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

  def stub_ssh(output: "", exit_code: 0, fingerprint: DEFAULT_FINGERPRINT)
    ssh = instance_double(Net::SSH::Connection::Session)
    channel = instance_double(Net::SSH::Connection::Channel)

    allow(Net::SSH).to receive(:start) do |_host, _user, opts = {}, &block|
      verifier = opts[:verify_host_key]

      if verifier.respond_to?(:verify)
        verifier.verify({ fingerprint: fingerprint, key: double("host_key") })
      elsif verifier.respond_to?(:call)
        verifier.call(double("host_key", fingerprint: fingerprint))
      end

      block&.call(ssh)
    end

    allow(ssh).to receive(:open_channel).and_yield(channel)
    allow(ssh).to receive(:loop)
    allow(channel).to receive(:exec).and_yield(channel, true)
    allow(channel).to receive(:on_data).and_yield(channel, output)
    allow(channel).to receive(:on_extended_data)
    allow(channel).to receive(:on_request) do |name, &blk|
      next unless name == "exit-status"

      data = instance_double(Net::SSH::Buffer)
      allow(data).to receive(:read_long).and_return(exit_code)
      blk.call(nil, data)
    end

    channel
  end
end

RSpec.configure do |config|
  config.include NetSSHHelpers
end
```

- [ ] **Step 3: Run full existing SSH service suite to confirm nothing breaks**

```bash
docker compose exec app bundle exec rspec spec/services/servers/ spec/jobs/servers/ --format documentation
```

Expected: all existing tests still PASS (the default fingerprint from the factory matches the default stub fingerprint).

- [ ] **Step 4: Commit**

```bash
git add spec/factories/servers.rb spec/support/net_ssh.rb
git commit -m "Add default fingerprint to server factory and update SSH stub"
```

---

### Task 6: Add `HostKeyVerifier` to `SSHService` (TDD)

**Files:**
- Modify: `app/services/servers/ssh_service.rb`
- Modify: `spec/services/servers/ssh_service_spec.rb`
- Modify: `spec/services/servers/connection_service_spec.rb`

- [ ] **Step 1: Write failing tests for `SSHService`**

Add to `spec/services/servers/ssh_service_spec.rb` (inside the existing `RSpec.describe` block):

```ruby
describe "host key verification" do
  context "when server has no fingerprint" do
    let(:server) { create(:server, fingerprint: nil) }

    before { stub_ssh }

    it "raises HostKeyMismatch" do
      expect { service.call }.to raise_error(Net::SSH::HostKeyMismatch)
    end
  end

  context "when server fingerprint matches" do
    let(:server) { create(:server, fingerprint: NetSSHHelpers::DEFAULT_FINGERPRINT) }

    before { stub_ssh(fingerprint: NetSSHHelpers::DEFAULT_FINGERPRINT) }

    it "connects successfully" do
      expect { service.call }.not_to raise_error
    end
  end

  context "when server fingerprint does not match" do
    let(:server) { create(:server, fingerprint: NetSSHHelpers::DEFAULT_FINGERPRINT) }

    before { stub_ssh(fingerprint: "SHA256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb") }

    it "raises HostKeyMismatch" do
      expect { service.call }.to raise_error(Net::SSH::HostKeyMismatch)
    end
  end

  context "when verify_host_key is disabled" do
    with_configuration "verify_host_key" => false

    let(:server) { create(:server, fingerprint: nil) }

    before { stub_ssh }

    it "connects without verifying the fingerprint" do
      expect { service.call }.not_to raise_error
    end
  end
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
docker compose exec app bundle exec rspec spec/services/servers/ssh_service_spec.rb -e "host key verification" --format documentation
```

Expected: FAIL — the `verify_host_key: :never` option currently never calls the verifier.

- [ ] **Step 3: Add `HostKeyVerifier` and swap `:never`**

Replace `app/services/servers/ssh_service.rb` with:

```ruby
# frozen_string_literal: true

module Servers
  class SSHService < ApplicationService
    CONNECT_TIMEOUT = 10

    attr_reader :server

    def initialize(server)
      super()

      @server = server
    end

    def call
      audit = Audit.create!(server:, command:, started_at: Time.zone.now) if Configuration.get("audits")

      output = +""
      exit_code = nil

      Net::SSH.start(server.host, server.username, ssh_options) do |ssh|
        ssh.open_channel do |channel|
          channel.exec(command) do |_ch, _success|
            channel.on_data { |_, data| output << data }
            channel.on_extended_data { |_, _, data| output << data }
            channel.on_request("exit-status") { |_, data| exit_code = data.read_long }
          end
        end

        ssh.loop
      end

      audit&.update!(output:, exit_status: exit_code, completed_at: Time.zone.now)

      output
    end

    protected

    def command
      raise NotImplementedError
    end

    private

    def ssh_options
      opts = {
        port: server.port,
        timeout: CONNECT_TIMEOUT,
        non_interactive: true,
        verify_host_key: verify_host_key_option,
      }

      if server.ssh_key.present?
        opts[:key_data] = [server.ssh_key]
        opts[:keys_only] = true
      elsif server.password.present?
        opts[:password] = server.password
        opts[:auth_methods] = ["password"]
      end

      opts
    end

    def verify_host_key_option
      Configuration.get("verify_host_key") ? HostKeyVerifier.new(server) : :never
    end

    class HostKeyVerifier
      def initialize(server)
        @server = server
      end

      def verify(options)
        raise Net::SSH::HostKeyMismatch if @server.fingerprint.blank?
        raise Net::SSH::HostKeyMismatch unless @server.fingerprint == options.fetch(:fingerprint)

        true
      end
    end
  end
end
```

- [ ] **Step 4: Run the new tests**

```bash
docker compose exec app bundle exec rspec spec/services/servers/ssh_service_spec.rb --format documentation
```

Expected: all tests PASS.

- [ ] **Step 5: Add fingerprint integration tests to `ConnectionService` spec**

Add to `spec/services/servers/connection_service_spec.rb` inside `describe "#call"`:

```ruby
context "when server fingerprint matches the host key" do
  let(:server) { create(:server, :with_password, fingerprint: NetSSHHelpers::DEFAULT_FINGERPRINT) }

  before { stub_ssh(output: "ok\n", fingerprint: NetSSHHelpers::DEFAULT_FINGERPRINT) }

  it "returns success" do
    expect(service.call).to eq(success: true)
  end
end

context "when server fingerprint does not match the host key" do
  let(:server) { create(:server, :with_password, fingerprint: NetSSHHelpers::DEFAULT_FINGERPRINT) }

  before { stub_ssh(fingerprint: "SHA256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb") }

  it "returns failure" do
    result = service.call
    expect(result[:success]).to be false
    expect(result[:message]).to include("HostKeyMismatch")
  end

  it "records the error on the server" do
    service.call

    server.reload

    expect(server.error_class).to eq("Net::SSH::HostKeyMismatch")
  end
end

context "when server has no fingerprint" do
  let(:server) { create(:server, :with_password, fingerprint: nil) }

  before { stub_ssh(output: "ok\n") }

  it "returns failure" do
    result = service.call
    expect(result[:success]).to be false
  end
end
```

- [ ] **Step 6: Run connection service tests**

```bash
docker compose exec app bundle exec rspec spec/services/servers/connection_service_spec.rb --format documentation
```

Expected: all tests PASS.

- [ ] **Step 7: Run the full SSH suite to catch regressions**

```bash
docker compose exec app bundle exec rspec spec/services/servers/ spec/jobs/servers/ --format documentation
```

Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
git add app/services/servers/ssh_service.rb spec/services/servers/ssh_service_spec.rb spec/services/servers/connection_service_spec.rb
git commit -m "Add host key fingerprint verification to SSHService"
```

---

### Task 7: `FingerprintService` (TDD)

**Files:**
- Create: `app/services/servers/fingerprint_service.rb`
- Create: `spec/services/servers/fingerprint_service_spec.rb`

- [ ] **Step 1: Write failing tests**

Create `spec/services/servers/fingerprint_service_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Servers::FingerprintService do
  subject(:service) { described_class.new(server) }

  let(:server) { build(:server, :with_password, fingerprint: nil) }

  describe "#call" do
    before { stub_ssh(fingerprint: NetSSHHelpers::DEFAULT_FINGERPRINT) }

    it "returns the server's host key fingerprint" do
      expect(service.call).to eq(NetSSHHelpers::DEFAULT_FINGERPRINT)
    end

    it "connects regardless of whether the server has a stored fingerprint" do
      server.fingerprint = nil

      expect { service.call }.not_to raise_error
    end

    it "connects regardless of a stored fingerprint mismatch" do
      server.fingerprint = "SHA256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

      expect { service.call }.not_to raise_error
    end

    context "with SSH key authentication" do
      let(:server) { build(:server, :with_ssh_key, fingerprint: nil) }

      it "returns the fingerprint" do
        expect(service.call).to eq(NetSSHHelpers::DEFAULT_FINGERPRINT)
      end
    end
  end
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
docker compose exec app bundle exec rspec spec/services/servers/fingerprint_service_spec.rb --format documentation
```

Expected: FAIL — `Servers::FingerprintService` is not defined.

- [ ] **Step 3: Implement `FingerprintService`**

Create `app/services/servers/fingerprint_service.rb`:

```ruby
# frozen_string_literal: true

module Servers
  class FingerprintService < ApplicationService
    CONNECT_TIMEOUT = 10

    attr_reader :server

    def initialize(server)
      super()

      @server = server
    end

    def call
      @captured_fingerprint = nil

      Net::SSH.start(server.host, server.username, ssh_options) { }

      @captured_fingerprint
    end

    private

    def ssh_options
      opts = {
        port: server.port,
        timeout: CONNECT_TIMEOUT,
        non_interactive: true,
        verify_host_key: CapturingVerifier.new(->(fp) { @captured_fingerprint = fp }),
      }

      if server.ssh_key.present?
        opts[:key_data] = [server.ssh_key]
        opts[:keys_only] = true
      elsif server.password.present?
        opts[:password] = server.password
        opts[:auth_methods] = ["password"]
      end

      opts
    end

    class CapturingVerifier
      def initialize(callback)
        @callback = callback
      end

      def verify(options)
        @callback.call(options.fetch(:fingerprint))
        true
      end
    end
  end
end
```

- [ ] **Step 4: Run tests**

```bash
docker compose exec app bundle exec rspec spec/services/servers/fingerprint_service_spec.rb --format documentation
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/servers/fingerprint_service.rb spec/services/servers/fingerprint_service_spec.rb
git commit -m "Add FingerprintService to fetch server host key fingerprint"
```

---

### Task 8: Fingerprint controller action + route + policy

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/servers_controller.rb`
- Modify: `app/policies/server_policy.rb`
- Modify: `config/locales/servers/en.yml`

- [ ] **Step 1: Add route**

In `config/routes.rb`, add `fingerprint` to the servers member block:

```ruby
resources :servers do
  member do
    post :test
    post :measure
    post :deploy
    post :fingerprint
  end
end
```

- [ ] **Step 2: Update route annotations**

```bash
docker compose exec app bundle exec annotaterb routes
```

- [ ] **Step 3: Add `fingerprint?` to policy**

In `app/policies/server_policy.rb`, add after `def deploy?`:

```ruby
def fingerprint?
  update?
end
```

- [ ] **Step 4: Add `fingerprint` action to controller**

In `app/controllers/servers_controller.rb`:

1. Add `:fingerprint` to the `before_action :set_server` line:

```ruby
before_action :set_server, only: [:edit, :update, :destroy, :measure, :deploy, :test, :fingerprint]
```

2. Add the action after `deploy`:

```ruby
def fingerprint
  authorize! @server, to: :fingerprint?

  @server.host = params[:host] if params[:host].present?
  @server.port = params[:port] if params[:port].present?
  @server.username = params[:username] if params[:username].present?
  @server.password = params[:password] if params[:password].present?
  @server.ssh_key = params[:ssh_key] if params[:ssh_key].present?

  if @server.host.blank? || @server.port.blank? || @server.username.blank? || (@server.password.blank? && @server.ssh_key.blank?)
    return render turbo_stream: turbo_stream.prepend(
      "notifications",
      partial: "shared/action_result",
      locals: {
        result: { success: false, message: t(".missing_details") },
        success_message: t(".success"),
        failure_message: t(".failure"),
      },
    )
  end

  fp = Servers::FingerprintService.call(@server)

  render turbo_stream: [
    turbo_stream.replace("server-fingerprint-field", partial: "servers/fingerprint_field", locals: { server: @server, fingerprint: fp }),
    turbo_stream.prepend(
      "notifications",
      partial: "shared/action_result",
      locals: {
        result: { success: true },
        success_message: t(".success"),
        failure_message: t(".failure"),
      },
    ),
  ]
rescue StandardError => e
  render turbo_stream: turbo_stream.prepend(
    "notifications",
    partial: "shared/action_result",
    locals: {
      result: { success: false, message: "#{e.class}: #{e.message}" },
      success_message: t(".success"),
      failure_message: t(".failure"),
    },
  )
end
```

- [ ] **Step 5: Add I18n strings**

In `config/locales/servers/en.yml`, add under `servers:`:

```yaml
    fingerprint:
      failure: Failed to fetch fingerprint
      missing_details: Host, port, username, and a password or SSH key are required to fetch the fingerprint.
      success: Fingerprint fetched successfully
    form:
      # (existing keys)
      fingerprint: Fingerprint
      fingerprint_fetch: Fetch
      fingerprint_hint: Verified on every connection
      fingerprint_placeholder: SHA256:...
```

- [ ] **Step 6: Permit `:fingerprint` in `server_params`**

In `app/controllers/servers_controller.rb`, add `:fingerprint` to the `permit` call in `server_params`:

```ruby
def server_params
  params
    .require(:server)
    .permit(
      :name,
      :description,
      :path,
      :operating_system,
      :host,
      :port,
      :username,
      :password,
      :ssh_key,
      :fingerprint,
    )
end
```

- [ ] **Step 7: Run rubocop**

```bash
docker compose exec app bundle exec rubocop app/controllers/servers_controller.rb app/policies/server_policy.rb config/routes.rb
```

Fix any offenses.

- [ ] **Step 8: Commit**

```bash
git add config/routes.rb app/controllers/servers_controller.rb app/policies/server_policy.rb config/locales/servers/en.yml
git commit -m "Add fingerprint endpoint to ServersController"
```

---

### Task 9: Form fingerprint field + Stimulus controller

**Files:**
- Create: `app/views/servers/_fingerprint_field.html.erb`
- Modify: `app/views/servers/_form.html.erb`
- Create: `app/javascript/controllers/server_fingerprint_controller.js`

- [ ] **Step 1: Create the fingerprint field partial**

Create `app/views/servers/_fingerprint_field.html.erb` (locals: `server`, `fingerprint`):

```erb
<div id="server-fingerprint-field" class="field">
  <label for="server_fingerprint"><%= I18n.t("servers.form.fingerprint") %></label>

  <div class="flex gap-2 items-start">
    <input
      type="text"
      id="server_fingerprint"
      name="server[fingerprint]"
      value="<%= fingerprint || server.fingerprint %>"
      placeholder="<%= I18n.t("servers.form.fingerprint_placeholder") %>"
      class="font-mono text-xs flex-1"
      autocomplete="off"
      data-server-fingerprint-target="input"
    >

    <% if server.persisted? %>
      <button
        type="button"
        class="btn-outline"
        data-server-fingerprint-target="button"
        data-action="click->server-fingerprint#fetch"
      >
        <span data-server-fingerprint-target="label"><%= I18n.t("servers.form.fingerprint_fetch") %></span>
        <%= lucide_icon "loader-circle",
                        class: "h-4 w-4 hidden animate-spin",
                        data: { "server-fingerprint-target": "spinner" } %>
      </button>
    <% end %>
  </div>

  <p class="text-sm text-muted-foreground flex items-center gap-2 mt-1">
    <%= lucide_icon "shield", class: "h-4 w-4 shrink-0" %>
    <%= I18n.t("servers.form.fingerprint_hint") %>
  </p>
</div>
```

- [ ] **Step 2: Add fingerprint section to the authentication card in `_form.html.erb`**

In `app/views/servers/_form.html.erb`, inside the authentication card `<section>`, after the closing `</div>` of the tabs controller div and before `</section>`, add:

```erb
      <div
        class="mt-6 pt-6 border-t border-border"
        data-controller="server-fingerprint"
        data-server-fingerprint-server-id-value="<%= server.id %>"
        data-server-fingerprint-url-value="<%= server.persisted? ? fingerprint_server_path(server) : '' %>"
      >
        <%= render "servers/fingerprint_field", server: server, fingerprint: nil %>
      </div>
```

- [ ] **Step 3: Create Stimulus controller**

Create `app/javascript/controllers/server_fingerprint_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "label", "spinner", "input"]
  static values = { url: String }

  async fetch() {
    this.#setLoading(true)

    try {
      const form = document.getElementById("server-form")
      const body = new FormData(form)

      const response = await window.fetch(this.urlValue, {
        method: "POST",
        headers: { Accept: "text/vnd.turbo-stream.html", "X-CSRF-Token": this.#csrfToken() },
        body,
      })

      const html = await response.text()
      Turbo.renderStreamMessage(html)
    } finally {
      this.#setLoading(false)
    }
  }

  #setLoading(loading) {
    if (this.hasButtonTarget) this.buttonTarget.disabled = loading
    if (this.hasLabelTarget) this.labelTarget.classList.toggle("hidden", loading)
    if (this.hasSpinnerTarget) this.spinnerTarget.classList.toggle("hidden", !loading)
  }

  #csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
```

- [ ] **Step 4: Register the controller**

In `app/javascript/controllers/index.js`, add:

```javascript
import ServerFingerprintController from "./server_fingerprint_controller"
application.register("server-fingerprint", ServerFingerprintController)
```

- [ ] **Step 5: Build JS assets**

```bash
docker compose exec app yarn build:js
```

Confirm no build errors.

- [ ] **Step 6: Format ERB files**

```bash
docker compose exec app yarn herb:format
```

- [ ] **Step 7: Commit**

```bash
git add app/views/servers/ app/javascript/controllers/
git commit -m "Add fingerprint field and fetch button to server form"
```

---

## Section 2 — Authentication

---

### Task 8: `SshConfigService` (TDD)

**Files:**
- Create: `app/services/servers/ssh_config_service.rb`
- Create: `spec/services/servers/ssh_config_service_spec.rb`

The service writes `~/.ssh/config` and per-server key/password files. It is machine-scoped (all users' servers) and idempotent.

- [ ] **Step 1: Write failing tests**

Create `spec/services/servers/ssh_config_service_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Servers::SshConfigService do
  subject(:service) { described_class.new(ssh_dir: tmpdir) }

  let(:tmpdir) { Pathname.new(Dir.mktmpdir) }

  after { FileUtils.rm_rf(tmpdir) }

  describe "#call" do
    context "with a key-auth server" do
      let!(:server) { create(:server, :with_ssh_key) }

      before { service.call }

      it "writes the private key to ~/.ssh/<uuid>" do
        key_file = tmpdir.join(server.id.to_s)
        expect(key_file).to exist
        expect(key_file.read).to eq(server.ssh_key)
      end

      it "sets the key file permissions to 0600" do
        key_file = tmpdir.join(server.id.to_s)
        expect(key_file.stat.mode & 0o777).to eq(0o600)
      end

      it "writes a Host stanza with IdentityFile" do
        config = tmpdir.join("config").read
        expect(config).to include("Host #{server.id}")
        expect(config).to include("HostName #{server.host}")
        expect(config).to include("Port #{server.port}")
        expect(config).to include("User #{server.username}")
        expect(config).to include("IdentityFile #{tmpdir.join(server.id.to_s)}")
        expect(config).to include("IdentitiesOnly yes")
      end

      it "does not write a password file for key-auth servers" do
        expect(tmpdir.join("#{server.id}_password")).not_to exist
      end
    end

    context "with a password-auth server" do
      let!(:server) { create(:server, :with_password) }

      before { service.call }

      it "writes the password to ~/.ssh/<uuid>_password" do
        password_file = tmpdir.join("#{server.id}_password")
        expect(password_file).to exist
        expect(password_file.read).to eq(server.password)
      end

      it "sets password file permissions to 0600" do
        password_file = tmpdir.join("#{server.id}_password")
        expect(password_file.stat.mode & 0o777).to eq(0o600)
      end

      it "writes a Host stanza without IdentityFile" do
        config = tmpdir.join("config").read
        expect(config).to include("Host #{server.id}")
        expect(config).not_to include("IdentityFile")
        expect(config).not_to include("IdentitiesOnly")
      end

      it "does not write a key file for password-auth servers" do
        expect(tmpdir.join(server.id.to_s)).not_to exist
      end
    end

    context "with a mixed fleet" do
      let!(:key_server) { create(:server, :with_ssh_key) }
      let!(:pass_server) { create(:server, :with_password) }

      before { service.call }

      it "includes stanzas for both servers" do
        config = tmpdir.join("config").read
        expect(config).to include("Host #{key_server.id}")
        expect(config).to include("Host #{pass_server.id}")
      end
    end

    context "with orphaned key files" do
      let!(:server) { create(:server, :with_ssh_key) }
      let(:orphan_id) { SecureRandom.uuid }

      before do
        tmpdir.join(orphan_id).write("orphan key")
        tmpdir.join("#{orphan_id}_password").write("orphan pass")
        service.call
      end

      it "removes the orphaned key file" do
        expect(tmpdir.join(orphan_id)).not_to exist
      end

      it "removes the orphaned password file" do
        expect(tmpdir.join("#{orphan_id}_password")).not_to exist
      end

      it "keeps files for existing servers" do
        expect(tmpdir.join(server.id.to_s)).to exist
      end
    end

    context "idempotency" do
      let!(:server) { create(:server, :with_ssh_key) }

      it "produces the same result when called twice" do
        service.call
        config_first = tmpdir.join("config").read

        service.call
        config_second = tmpdir.join("config").read

        expect(config_first).to eq(config_second)
      end
    end

    it "sets the config file permissions to 0600" do
      create(:server, :with_password)
      service.call

      expect((tmpdir.join("config").stat.mode & 0o777)).to eq(0o600)
    end

    it "includes a managed-by header comment" do
      create(:server)
      service.call

      expect(tmpdir.join("config").read).to start_with("# Managed by rsync-ui")
    end
  end
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
docker compose exec app bundle exec rspec spec/services/servers/ssh_config_service_spec.rb --format documentation
```

Expected: FAIL — `Servers::SshConfigService` is not defined.

- [ ] **Step 3: Implement `SshConfigService`**

Create `app/services/servers/ssh_config_service.rb`:

```ruby
# frozen_string_literal: true

module Servers
  class SshConfigService < ApplicationService
    SSH_DIR = Pathname.new(Dir.home).join(".ssh").freeze

    UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

    def initialize(ssh_dir: SSH_DIR)
      super()

      @ssh_dir = Pathname.new(ssh_dir)
    end

    def call
      @ssh_dir.mkpath
      @ssh_dir.chmod(0o700)

      servers = Server.all.to_a
      server_ids = servers.map { |s| s.id.to_s }

      write_credentials(servers, server_ids)
      cleanup_orphans(server_ids)
      write_config(servers)
    end

    private

    def write_credentials(servers, _server_ids)
      servers.each do |server|
        if server.ssh_key.present?
          key_path = @ssh_dir.join(server.id.to_s)
          key_path.write(server.ssh_key)
          key_path.chmod(0o600)
        elsif server.password.present?
          pass_path = @ssh_dir.join("#{server.id}_password")
          pass_path.write(server.password)
          pass_path.chmod(0o600)
        end
      end
    end

    def cleanup_orphans(server_ids)
      @ssh_dir.each_child do |path|
        next if path.basename.to_s == "config"

        stem = path.basename.to_s.sub(/_password\z/, "")
        next unless UUID_PATTERN.match?(stem)
        next if server_ids.include?(stem)

        path.delete
      end
    end

    def write_config(servers)
      lines = ["# Managed by rsync-ui — do not edit manually\n"]

      servers.each do |server|
        lines << render_stanza(server)
      end

      config_path = @ssh_dir.join("config")
      tmp_path = @ssh_dir.join("config.tmp")
      tmp_path.write(lines.join("\n"))
      tmp_path.chmod(0o600)
      File.rename(tmp_path, config_path)
    end

    def render_stanza(server)
      lines = [
        "Host #{server.id}",
        "  HostName #{server.host}",
        "  Port #{server.port}",
        "  User #{server.username}",
        "  StrictHostKeyChecking no",
        "  UserKnownHostsFile /dev/null",
      ]

      if server.ssh_key.present?
        lines << "  IdentityFile #{@ssh_dir.join(server.id.to_s)}"
        lines << "  IdentitiesOnly yes"
      end

      lines.join("\n")
    end
  end
end
```

- [ ] **Step 4: Run tests**

```bash
docker compose exec app bundle exec rspec spec/services/servers/ssh_config_service_spec.rb --format documentation
```

Expected: all tests PASS.

- [ ] **Step 5: Run rubocop**

```bash
docker compose exec app bundle exec rubocop app/services/servers/ssh_config_service.rb
```

Fix any offenses.

- [ ] **Step 6: Commit**

```bash
git add app/services/servers/ssh_config_service.rb spec/services/servers/ssh_config_service_spec.rb
git commit -m "Add SshConfigService to manage ~/.ssh/config and key files"
```

---

### Task 9: `SyncSshConfigJob` + `Server` callbacks (TDD)

**Files:**
- Create: `app/jobs/servers/sync_ssh_config_job.rb`
- Create: `spec/jobs/servers/sync_ssh_config_job_spec.rb`
- Modify: `app/models/server.rb`
- Modify: `spec/models/server_spec.rb`

- [ ] **Step 1: Write failing job tests**

Create `spec/jobs/servers/sync_ssh_config_job_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Servers::SyncSshConfigJob do
  describe "#perform" do
    it "calls SshConfigService" do
      allow(Servers::SshConfigService).to receive(:call)

      described_class.perform_now

      expect(Servers::SshConfigService).to have_received(:call)
    end
  end
end
```

- [ ] **Step 2: Write failing callback tests**

Add to `spec/models/server_spec.rb`:

```ruby
describe "callbacks" do
  it "enqueues SyncSshConfigJob after create" do
    expect { create(:server) }
      .to have_enqueued_job(Servers::SyncSshConfigJob)
  end

  it "enqueues SyncSshConfigJob after update" do
    server = create(:server)

    expect { server.update!(name: "new name") }
      .to have_enqueued_job(Servers::SyncSshConfigJob)
  end

  it "enqueues SyncSshConfigJob after destroy" do
    server = create(:server)

    expect { server.destroy! }
      .to have_enqueued_job(Servers::SyncSshConfigJob)
  end
end
```

- [ ] **Step 3: Run tests to confirm they fail**

```bash
docker compose exec app bundle exec rspec spec/jobs/servers/sync_ssh_config_job_spec.rb spec/models/server_spec.rb -e "callbacks" --format documentation
```

Expected: FAIL.

- [ ] **Step 4: Create the job**

Create `app/jobs/servers/sync_ssh_config_job.rb`:

```ruby
# frozen_string_literal: true

module Servers
  class SyncSshConfigJob < ApplicationJob
    def perform
      SshConfigService.call
    end
  end
end
```

- [ ] **Step 5: Add callbacks to `Server`**

In `app/models/server.rb`, add after the `before_validation` line:

```ruby
after_create_commit  :sync_ssh_config
after_update_commit  :sync_ssh_config
after_destroy_commit :sync_ssh_config
```

And add the private method at the bottom of the `private` section:

```ruby
def sync_ssh_config
  Servers::SyncSshConfigJob.perform_later
end
```

- [ ] **Step 6: Run tests**

```bash
docker compose exec app bundle exec rspec spec/jobs/servers/sync_ssh_config_job_spec.rb spec/models/server_spec.rb --format documentation
```

Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add app/jobs/servers/sync_ssh_config_job.rb spec/jobs/servers/sync_ssh_config_job_spec.rb app/models/server.rb spec/models/server_spec.rb
git commit -m "Add SyncSshConfigJob and Server commit callbacks"
```

---

### Task 10: Startup initializer

**Files:**
- Create: `config/initializers/ssh_config.rb`

- [ ] **Step 1: Create initializer**

Create `config/initializers/ssh_config.rb`:

```ruby
# frozen_string_literal: true

Rails.application.config.after_initialize do
  next if Rails.env.test?

  Servers::SyncSshConfigJob.perform_later
end
```

- [ ] **Step 2: Commit**

```bash
git add config/initializers/ssh_config.rb
git commit -m "Enqueue SyncSshConfigJob on application startup"
```

---

### Task 11: Update `Rsync::CommandService` (TDD)

**Files:**
- Modify: `app/services/rsync/command_service.rb`
- Modify: `spec/services/rsync/command_service_spec.rb`

The changes:
1. `ssh_flags` emits `-e "ssh -F <config_path>"` for key-auth remote servers and `-e "sshpass -f <pass_file> ssh -F <config_path>"` for password-auth servers.
2. `repository_path` for remote repos changes from `user@host:path` to `server_uuid:path`.
3. `non_standard_port` is removed (port now handled by SSH config).

- [ ] **Step 1: Write failing tests**

In `spec/services/rsync/command_service_spec.rb`, replace the `describe "remote repositories"` block with:

```ruby
describe "remote repositories" do
  let(:ssh_home) { Pathname.new(Dir.home).join(".ssh") }
  let(:server) { build(:server, :with_ssh_key) }
  let(:source) { build(:repository, :remote, server:, path: "/data/source") }

  it "uses server UUID as hostname in the path" do
    expect(command).to include("#{server.id}:/data/source")
  end

  it "does not include user@host in the path" do
    expect(command).not_to include("@")
  end

  it "includes the SSH config flag" do
    expect(command).to include("-e \"ssh -F #{ssh_home}/config\"")
  end

  context "with password authentication" do
    let(:server) { build(:server, :with_password) }

    it "includes sshpass with the password file" do
      expect(command).to include("-e \"sshpass -f #{ssh_home}/#{server.id}_password ssh -F #{ssh_home}/config\"")
    end
  end

  context "with a non-standard SSH port" do
    let(:server) { build(:server, :with_ssh_key, port: 2222) }

    it "does not include a port flag (handled by SSH config)" do
      expect(command).not_to include("-p 2222")
    end

    it "still includes the SSH config flag" do
      expect(command).to include("-e \"ssh -F #{ssh_home}/config\"")
    end
  end

  context "with local-only repositories" do
    let(:source) { build(:repository, :local, path: "/data/source") }
    let(:destination) { build(:repository, :local, path: "/data/destination") }

    it "omits the SSH flag entirely" do
      expect(command).not_to include("-e")
    end
  end
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
docker compose exec app bundle exec rspec spec/services/rsync/command_service_spec.rb -e "remote repositories" --format documentation
```

Expected: FAIL — current code uses `user@host:path` format and `-e "ssh -p <port>"`.

- [ ] **Step 3: Update `CommandService`**

Replace `app/services/rsync/command_service.rb`:

```ruby
# frozen_string_literal: true

module Rsync
  class CommandService < ApplicationService
    BASIC_FLAGS = {
      opt_archive: "--archive",
      opt_recursive: "--recursive",
      opt_relative: "--relative",
      opt_links: "--links",
      opt_times: "--times",
      opt_perms: "--perms",
      opt_owner: "--owner",
      opt_group: "--group",
      opt_one_file_system: "--one-file-system",
      opt_delete: "--delete",
      opt_delete_excluded: "--delete-excluded",
      opt_existing: "--existing",
      opt_ignore_existing: "--ignore-existing",
      opt_update: "--update",
      opt_dry_run: "--dry-run",
      opt_inplace: "--inplace",
      opt_size_only: "--size-only",
      opt_progress: "--progress",
    }.freeze

    ADVANCED_FLAGS = {
      opt_acls: "--acls",
      opt_xattrs: "--xattrs",
      opt_hard_links: "--hard-links",
      opt_devices: "--devices",
      opt_specials: "--specials",
      opt_checksum: "--checksum",
      opt_compress: "--compress",
      opt_partial: "--partial",
      opt_backup: "--backup",
      opt_append: "--append",
      opt_numeric_ids: "--numeric-ids",
      opt_itemize_changes: "--itemize-changes",
      opt_secluded_args: "--secluded-args",
      opt_verbose: "--verbose",
      opt_progress2: "--info=progress2",
      opt_no_inc_recursive: "--no-inc-recursive",
    }.freeze

    attr_reader :job

    def initialize(job:)
      super()

      @job = job
    end

    def call
      parts.join(" ")
    end

    def parts
      [
        rsync_path,
        *ssh_flags,
        *boolean_flags(BASIC_FLAGS),
        *boolean_flags(ADVANCED_FLAGS),
        *custom_argument_flags,
        *include_flags,
        *exclude_flags,
        source_path,
        destination_path,
      ].compact
    end

    private

    def rsync_path
      [
        ("sudo" if job.opt_superuser),
        job.opt_rsync_path.presence || "rsync",
      ].compact.join(" ")
    end

    def boolean_flags(map)
      map.filter_map { |attr, flag| flag if job.public_send(attr) }
    end

    def ssh_flags
      server = remote_server
      return [] unless server

      if server.ssh_key.present?
        ["-e \"ssh -F #{ssh_home}/config\""]
      else
        ["-e \"sshpass -f #{ssh_home}/#{server.id}_password ssh -F #{ssh_home}/config\""]
      end
    end

    def remote_server
      [job.source_repository, job.destination_repository]
        .compact
        .find(&:remote?)
        &.server
    end

    def ssh_home
      @ssh_home ||= Pathname.new(Dir.home).join(".ssh")
    end

    def custom_argument_flags
      job.opt_arguments.present? ? [job.opt_arguments.strip] : []
    end

    def include_flags
      job.opt_include.map { |pattern| "--include=#{pattern}" }
    end

    def exclude_flags
      job.opt_exclude.map { |pattern| "--exclude=#{pattern}" }
    end

    def source_path
      repository_path(job.source_repository) || "<source>"
    end

    def destination_path
      repository_path(job.destination_repository) || "<destination>"
    end

    def repository_path(repo)
      return nil if repo.blank?

      if repo.remote? && repo.server.present?
        "#{repo.server.id}:#{repo.path}"
      else
        repo.path
      end
    end
  end
end
```

- [ ] **Step 4: Run the full command service spec**

```bash
docker compose exec app bundle exec rspec spec/services/rsync/command_service_spec.rb --format documentation
```

Expected: all tests PASS. (The old `user@host:path` and `-e "ssh -p <port>"` tests have been replaced.)

- [ ] **Step 5: Run rubocop**

```bash
docker compose exec app bundle exec rubocop app/services/rsync/command_service.rb
```

- [ ] **Step 6: Commit**

```bash
git add app/services/rsync/command_service.rb spec/services/rsync/command_service_spec.rb
git commit -m "Update CommandService to use SSH config and server UUID paths"
```

---

### Task 12: Dockerfile + docs

**Files:**
- Modify: `Dockerfile`
- Modify: `docs/COMMANDS.md`

- [ ] **Step 1: Add `sshpass` to Alpine runtime dependencies**

In `Dockerfile`, update the `RUNTIME_DEPS` line:

```dockerfile
ENV RUNTIME_DEPS postgresql gmp vips openssh rsync python3 py3-pip sshpass
```

- [ ] **Step 2: Update COMMANDS.md**

In `docs/COMMANDS.md`, under `## Initial Setup`, add a note:

```markdown
**System Prerequisites (already in Docker image):**
- `sshpass` — used by rsync for password-based SSH authentication
```

- [ ] **Step 3: Commit**

```bash
git add Dockerfile docs/COMMANDS.md
git commit -m "Add sshpass to Docker runtime dependencies"
```

---

## Post-Implementation

After all tasks are complete, run the full test suite to confirm no regressions:

```bash
docker compose exec app bundle exec rspec --format progress
```

And run rubocop across all modified files:

```bash
docker compose exec app bundle exec rubocop app/models/server.rb app/services/servers/ app/services/rsync/command_service.rb app/controllers/servers_controller.rb app/jobs/servers/ app/policies/server_policy.rb
```
