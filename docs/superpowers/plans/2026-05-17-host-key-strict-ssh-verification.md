# Host Key Strict SSH Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `StrictHostKeyChecking no` in the generated SSH config with per-server `known_hosts` files populated from a stored host public key, making rsync connections MITM-resistant.

**Architecture:** Add a `host_key` (text) column to `servers`. Extend `CaptureService` to capture the full public key alongside the fingerprint during SSH connection. Save both fields to the DB in the `fingerprint` controller action. `SSHConfigService` writes a per-server `_known_hosts` file (populated or empty/fail-closed) and uses `StrictHostKeyChecking yes`.

**Tech Stack:** Rails 8, Net::SSH, PostgreSQL, Turbo Streams, Stimulus

---

## File Map

| File | Change |
|------|--------|
| `spec/support/net_ssh.rb` | Add `DEFAULT_HOST_KEY_BLOB`, `DEFAULT_HOST_KEY`; pass `key:` to verifier |
| `db/migrate/TIMESTAMP_add_host_key_to_servers.rb` | New: add `host_key` text column |
| `app/models/server.rb` | Add `host_key` format validation |
| `spec/factories/servers.rb` | Add `:with_host_key` trait |
| `app/services/servers/host_key_verification/capture_service.rb` | Capture `options[:key]`; expose `host_key` reader |
| `spec/services/servers/host_key_verification/capture_service_spec.rb` | New spec |
| `app/services/servers/fingerprint_service.rb` | Return `host_key` in result hash |
| `spec/services/servers/fingerprint_service_spec.rb` | Assert `host_key` is returned |
| `app/controllers/servers_controller.rb` | Save both fields to DB in `#fingerprint`; remove `:fingerprint` from `server_params`; remove fingerprint override in `#test` |
| `spec/requests/servers_request_spec.rb` | Assert DB save; remove fingerprint-override tests |
| `app/views/servers/_fingerprint.html.erb` | Replace editable input with read-only display |
| `app/views/servers/_form.html.erb` | Remove fingerprint hidden field from test connection form |
| `app/javascript/controllers/server_test_controller.js` | Remove `fingerprint` target and sync line |
| `config/locales/servers/en.yml` | Add `fingerprint_none` key |
| `app/services/servers/ssh_config_service.rb` | Write `_known_hosts` files; use `StrictHostKeyChecking yes` |
| `spec/services/servers/ssh_config_service_spec.rb` | Add known_hosts tests |

---

## Task 1: Extend NetSSHHelpers to pass host key in stubs

**Files:**
- Modify: `spec/support/net_ssh.rb`

This must be done first — all later specs depend on the stub passing a `key:` option.

- [ ] **Step 1: Update the helper**

Replace `spec/support/net_ssh.rb` with:

```ruby
# frozen_string_literal: true

module NetSSHHelpers
  DEFAULT_FINGERPRINT = "SHA256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  DEFAULT_HOST_KEY_BLOB = "test-key-blob"
  DEFAULT_HOST_KEY = "ssh-ed25519 #{Base64.strict_encode64(DEFAULT_HOST_KEY_BLOB)}"

  def stub_ssh(output: "", exit_code: 0, fingerprint: DEFAULT_FINGERPRINT)
    key = double("host_key", ssh_type: "ssh-ed25519", to_blob: DEFAULT_HOST_KEY_BLOB)

    ssh = instance_double(Net::SSH::Connection::Session)
    channel = instance_double(Net::SSH::Connection::Channel)

    allow(Net::SSH)
      .to receive(:start) do |_host, _user, opts = {}, &block|
        if (verifier = opts[:verify_host_key]) && verifier.respond_to?(:verify)
          verifier.verify({ fingerprint:, key: })
        end

        block.call(ssh)
      end

    allow(ssh)
      .to receive(:open_channel)
      .and_yield(channel)

    allow(ssh)
      .to receive(:loop)

    allow(channel)
      .to receive(:exec)
      .and_yield(channel, true)

    allow(channel)
      .to receive(:on_data)
      .and_yield(channel, output)

    allow(channel)
      .to receive(:on_extended_data)

    allow(channel)
      .to receive(:on_request) do |name, &block|
      next unless name == "exit-status"

      data = instance_double(Net::SSH::Buffer)

      allow(data)
        .to receive(:read_long)
        .and_return(exit_code)

      block.call(nil, data)
    end

    channel
  end
end

RSpec.configure do |config|
  config.include NetSSHHelpers
end
```

- [ ] **Step 2: Run existing SSH specs to verify nothing broke**

```
docker compose exec app bundle exec rspec spec/services/servers/ssh_service_spec.rb spec/services/servers/fingerprint_service_spec.rb spec/services/servers/connection_service_spec.rb -f documentation
```

Expected: all pass (the new `key:` in `verify` is ignored by existing verifiers since `VerifyService` only reads `options[:fingerprint]`).

- [ ] **Step 3: Commit**

```bash
git add spec/support/net_ssh.rb
git commit -m "Pass host key object to verifier in SSH test stub"
```

---

## Task 2: Add host_key column and model validation

**Files:**
- Create: `db/migrate/TIMESTAMP_add_host_key_to_servers.rb`
- Modify: `app/models/server.rb`
- Modify: `spec/factories/servers.rb`

- [ ] **Step 1: Write a failing model validation test**

Add to `spec/models/server_spec.rb` (or create it if it doesn't exist). Find the validation block and add:

```ruby
describe "validations" do
  describe "#host_key" do
    it "is valid when blank" do
      server = build(:server, host_key: nil)
      expect(server).to be_valid
    end

    it "is valid for ssh-ed25519 keys" do
      server = build(:server, host_key: "ssh-ed25519 AAAA1234567890abcdefABCDEF==")
      expect(server).to be_valid
    end

    it "is valid for ssh-rsa keys" do
      server = build(:server, host_key: "ssh-rsa AAAA1234567890abcdefABCDEF==")
      expect(server).to be_valid
    end

    it "is invalid for unrecognised key types" do
      server = build(:server, host_key: "not-a-key-type AAAA1234")
      expect(server).not_to be_valid
      expect(server.errors[:host_key]).to be_present
    end
  end
end
```

- [ ] **Step 2: Run to confirm it fails**

```
docker compose exec app bundle exec rspec spec/models/server_spec.rb -e "host_key" -f documentation
```

Expected: FAIL — column does not exist yet.

- [ ] **Step 3: Generate and run the migration**

```
docker compose exec app rails generate migration AddHostKeyToServers host_key:text
```

Confirm `rails db:migrate` with the user, then run:

```
docker compose exec app rails db:migrate
```

- [ ] **Step 4: Add validation to the model**

In `app/models/server.rb`, add after the existing `validates :fingerprint` block:

```ruby
validates :host_key,
          format: { with: /\A(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) [A-Za-z0-9+\/=]+\z/ },
          allow_blank: true
```

- [ ] **Step 5: Add factory trait**

In `spec/factories/servers.rb`, add inside the `factory :server` block:

```ruby
trait :with_host_key do
  host_key { NetSSHHelpers::DEFAULT_HOST_KEY }
end
```

- [ ] **Step 6: Run tests to confirm they pass**

```
docker compose exec app bundle exec rspec spec/models/server_spec.rb -e "host_key" -f documentation
```

Expected: all pass.

- [ ] **Step 7: Update model annotations**

```
docker compose exec app bundle exec annotaterb models
```

- [ ] **Step 8: Commit**

```bash
git add db/migrate/ app/models/server.rb spec/factories/servers.rb spec/models/server_spec.rb
git commit -m "Add host_key column to servers"
```

---

## Task 3: Extend CaptureService to capture the host public key

**Files:**
- Modify: `app/services/servers/host_key_verification/capture_service.rb`
- Create: `spec/services/servers/host_key_verification/capture_service_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/services/servers/host_key_verification/capture_service_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Servers::HostKeyVerification::CaptureService do
  subject(:service) { described_class.new }

  let(:key) { double("host_key", ssh_type: "ssh-ed25519", to_blob: NetSSHHelpers::DEFAULT_HOST_KEY_BLOB) }

  describe "#verify" do
    before { service.verify({ fingerprint: NetSSHHelpers::DEFAULT_FINGERPRINT, key: }) }

    it "captures the fingerprint" do
      expect(service.fingerprint).to eq(NetSSHHelpers::DEFAULT_FINGERPRINT)
    end

    it "captures the host key in OpenSSH public key format" do
      expect(service.host_key).to eq(NetSSHHelpers::DEFAULT_HOST_KEY)
    end

    it "returns true" do
      result = service.verify({ fingerprint: NetSSHHelpers::DEFAULT_FINGERPRINT, key: })
      expect(result).to be(true)
    end
  end

  describe "#host_key" do
    it "is nil before verify is called" do
      expect(service.host_key).to be_nil
    end
  end
end
```

- [ ] **Step 2: Run to confirm it fails**

```
docker compose exec app bundle exec rspec spec/services/servers/host_key_verification/capture_service_spec.rb -f documentation
```

Expected: FAIL — `host_key` method undefined.

- [ ] **Step 3: Update CaptureService**

Replace `app/services/servers/host_key_verification/capture_service.rb`:

```ruby
# frozen_string_literal: true

module Servers
  module HostKeyVerification
    class CaptureService < ApplicationService
      attr_reader :fingerprint, :host_key

      def verify(options) # rubocop:disable Naming/PredicateMethod
        @fingerprint = options[:fingerprint]
        @host_key = "#{options[:key].ssh_type} #{Base64.strict_encode64(options[:key].to_blob)}" if options[:key]

        true
      end
    end
  end
end
```

- [ ] **Step 4: Run the spec to confirm it passes**

```
docker compose exec app bundle exec rspec spec/services/servers/host_key_verification/capture_service_spec.rb -f documentation
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/servers/host_key_verification/capture_service.rb spec/services/servers/host_key_verification/capture_service_spec.rb
git commit -m "Capture full host public key in CaptureService"
```

---

## Task 4: Update FingerprintService and controller to save host_key to DB

**Files:**
- Modify: `app/services/servers/fingerprint_service.rb`
- Modify: `spec/services/servers/fingerprint_service_spec.rb`
- Modify: `app/controllers/servers_controller.rb`
- Modify: `spec/requests/servers_request_spec.rb`

- [ ] **Step 1: Update the FingerprintService spec**

In `spec/services/servers/fingerprint_service_spec.rb`, add an assertion for `host_key`:

```ruby
RSpec.describe Servers::FingerprintService do
  subject(:service) { described_class.new(server) }

  let(:server) { create(:server, fingerprint: nil) }

  describe "#call" do
    before { stub_ssh(fingerprint: NetSSHHelpers::DEFAULT_FINGERPRINT) }

    it "returns the host key fingerprint" do
      result = service.call

      expect(result[:fingerprint]).to eq(NetSSHHelpers::DEFAULT_FINGERPRINT)
    end

    it "returns the host public key" do
      result = service.call

      expect(result[:host_key]).to eq(NetSSHHelpers::DEFAULT_HOST_KEY)
    end

    it "connects regardless of stored fingerprint" do
      expect { service.call }.not_to raise_error
    end
  end
end
```

- [ ] **Step 2: Run to confirm it fails**

```
docker compose exec app bundle exec rspec spec/services/servers/fingerprint_service_spec.rb -f documentation
```

Expected: FAIL — `host_key` key missing from result.

- [ ] **Step 3: Update FingerprintService**

Replace `app/services/servers/fingerprint_service.rb`:

```ruby
# frozen_string_literal: true

module Servers
  class FingerprintService < SSHService
    def call
      super

      { success: true, fingerprint: @capturing_verifier&.fingerprint, host_key: @capturing_verifier&.host_key }
    rescue StandardError => e
      { success: false, message: "#{e.class}: #{e.message}" }
    end

    protected

    def command
      "true"
    end

    private

    def verify_host_key
      @capturing_verifier = HostKeyVerification::CaptureService.new
    end
  end
end
```

- [ ] **Step 4: Run FingerprintService spec to confirm it passes**

```
docker compose exec app bundle exec rspec spec/services/servers/fingerprint_service_spec.rb -f documentation
```

Expected: all pass.

- [ ] **Step 5: Update the request spec for the fingerprint action**

Find the `describe "POST /servers/:id/fingerprint"` block in `spec/requests/servers_request_spec.rb`. Inside the `"when authenticated"` context, add:

```ruby
it "saves the fingerprint and host key to the server record" do
  expect {
    post fingerprint_server_path(server), headers: { "Accept" => "text/vnd.turbo-stream.html" }
  }.to change { server.reload.fingerprint }.to(NetSSHHelpers::DEFAULT_FINGERPRINT)
    .and change { server.reload.host_key }.to(NetSSHHelpers::DEFAULT_HOST_KEY)
end
```

Also find and **remove** these two tests from the `describe "POST /servers/:id/test"` block:

```ruby
it "uses server fingerprint when fingerprint param is blank" do ...
it "overrides server fingerprint with fingerprint param when present" do ...
```

- [ ] **Step 6: Run the relevant request specs to confirm the new test fails**

```
docker compose exec app bundle exec rspec spec/requests/servers_request_spec.rb -e "saves the fingerprint and host key" -f documentation
```

Expected: FAIL — controller doesn't save to DB yet.

- [ ] **Step 7: Update the controller**

In `app/controllers/servers_controller.rb`, make these three changes:

**1. In `#fingerprint`, save to DB after a successful fetch.** Find the `if result[:success]` block and update it to:

```ruby
if result[:success]
  @server.update!(fingerprint: result[:fingerprint], host_key: result[:host_key])

  streams << turbo_stream.replace(
    "server_fingerprint",
    partial: "servers/fingerprint",
    locals: { fingerprint: result[:fingerprint] },
  )
end
```

**2. In `#test`, remove the fingerprint override line.** Delete:

```ruby
@server.fingerprint = params[:fingerprint] if params[:fingerprint].present?
```

**3. In `server_params`, remove `:fingerprint` from the permitted list:**

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
    )
end
```

- [ ] **Step 8: Run all fingerprint and test-action request specs**

```
docker compose exec app bundle exec rspec spec/requests/servers_request_spec.rb -e "fingerprint" -e "test" -f documentation
```

Expected: all pass. The removed fingerprint-override tests no longer exist; the new DB-save test passes.

- [ ] **Step 9: Commit**

```bash
git add app/services/servers/fingerprint_service.rb spec/services/servers/fingerprint_service_spec.rb app/controllers/servers_controller.rb spec/requests/servers_request_spec.rb
git commit -m "Save host_key and fingerprint to DB on fingerprint fetch"
```

---

## Task 5: Update form views and Stimulus controller

**Files:**
- Modify: `app/views/servers/_fingerprint.html.erb`
- Modify: `app/views/servers/_form.html.erb`
- Modify: `app/javascript/controllers/server_test_controller.js`
- Modify: `config/locales/servers/en.yml`

- [ ] **Step 1: Add the missing locale key**

In `config/locales/servers/en.yml`, find the `form:` section and add under `fingerprint_hint:`:

```yaml
fingerprint_none: Not yet fetched
```

- [ ] **Step 2: Replace the fingerprint partial with a read-only display**

Replace `app/views/servers/_fingerprint.html.erb`:

```erb
<div id="server_fingerprint" class="grow">
  <% if fingerprint.present? %>
    <p class="font-mono text-sm break-all"><%= fingerprint %></p>
  <% else %>
    <p class="text-sm text-muted-foreground"><%= I18n.t("servers.form.fingerprint_none") %></p>
  <% end %>
</div>
```

- [ ] **Step 3: Remove the fingerprint hidden field from the test connection form**

In `app/views/servers/_form.html.erb`, find and delete this line inside the test connection `form_with` block:

```erb
<%= cf.hidden_field :fingerprint, data: { "server-test-target": "fingerprint" } %>
```

- [ ] **Step 4: Update server_test_controller.js**

In `app/javascript/controllers/server_test_controller.js`:

Remove `"fingerprint"` from `static targets`:
```javascript
static targets = ["button", "icon", "spinner", "host", "port", "username", "password", "sshKey", "serverId"]
```

Remove the fingerprint sync line from the `sync()` method:
```javascript
sync() {
  const form = document.getElementById(this.sourceFormValue)
  this.hostTarget.value = form.querySelector("[name='server[host]']").value
  this.portTarget.value = form.querySelector("[name='server[port]']").value
  this.usernameTarget.value = form.querySelector("[name='server[username]']").value
  this.passwordTarget.value = form.querySelector("[name='server[password]']").value
  this.sshKeyTarget.value = form.querySelector("[name='server[ssh_key]']").value
}
```

- [ ] **Step 5: Format ERB files**

```
docker compose exec app yarn herb:format
```

- [ ] **Step 6: Normalize i18n files**

```
docker compose exec app bundle exec i18n-tasks normalize
```

- [ ] **Step 7: Run the full test suite to catch any regressions**

```
docker compose exec app bundle exec rspec spec/requests/servers_request_spec.rb -f documentation
```

Expected: all pass.

- [ ] **Step 8: Commit**

```bash
git add app/views/servers/_fingerprint.html.erb app/views/servers/_form.html.erb app/javascript/controllers/server_test_controller.js config/locales/servers/en.yml
git commit -m "Show fingerprint as read-only display; remove editable fingerprint input"
```

---

## Task 6: Update SSHConfigService to write per-server known_hosts files

**Files:**
- Modify: `app/services/servers/ssh_config_service.rb`
- Modify: `spec/services/servers/ssh_config_service_spec.rb`

- [ ] **Step 1: Write failing specs**

In `spec/services/servers/ssh_config_service_spec.rb`, add a new context inside `describe "#call"`:

```ruby
context "with a server that has a host key" do
  let!(:server) { create(:server, :with_password, :with_host_key) }

  before { service.call }

  it "writes a known_hosts file with the server's host key entry" do
    known_hosts = tmpdir.join("#{server.slug}_known_hosts").read

    expect(known_hosts).to eq("[#{server.host}]:#{server.port} #{server.host_key}\n")
  end

  it "sets correct permissions on the known_hosts file" do
    expect(tmpdir.join("#{server.slug}_known_hosts").stat.mode & 0o777).to eq(0o600)
  end

  it "uses StrictHostKeyChecking yes in the SSH config" do
    config = tmpdir.join("config").read

    expect(config).to include("StrictHostKeyChecking yes")
    expect(config).not_to include("StrictHostKeyChecking no")
  end

  it "points UserKnownHostsFile to the per-server known_hosts file" do
    config = tmpdir.join("config").read

    expect(config).to include("UserKnownHostsFile #{tmpdir.join("#{server.slug}_known_hosts")}")
    expect(config).not_to include("UserKnownHostsFile /dev/null")
  end
end

context "with a server that has no host key" do
  let!(:server) { create(:server, :with_password, host_key: nil) }

  before { service.call }

  it "writes an empty known_hosts file" do
    known_hosts = tmpdir.join("#{server.slug}_known_hosts")

    expect(known_hosts).to exist
    expect(known_hosts.read).to eq("")
  end

  it "still uses StrictHostKeyChecking yes" do
    config = tmpdir.join("config").read

    expect(config).to include("StrictHostKeyChecking yes")
  end
end
```

Also add to the orphaned files context:

```ruby
context "with orphaned known_hosts files" do
  let!(:server) { create(:server, :with_password) }
  let(:orphan_slug) { "deleted-server" }

  before do
    tmpdir.join("#{orphan_slug}_known_hosts").write("orphan entry")
    service.call
  end

  it "removes the orphaned known_hosts file" do
    expect(tmpdir.join("#{orphan_slug}_known_hosts")).not_to exist
  end
end
```

- [ ] **Step 2: Run to confirm they fail**

```
docker compose exec app bundle exec rspec spec/services/servers/ssh_config_service_spec.rb -f documentation
```

Expected: new contexts FAIL.

- [ ] **Step 3: Update SSHConfigService**

Replace `app/services/servers/ssh_config_service.rb`:

```ruby
# frozen_string_literal: true

module Servers
  class SSHConfigService < ApplicationService
    SSH_DIR = Pathname.new(Dir.home).join(".ssh").freeze

    attr_reader :ssh_dir

    def initialize(ssh_dir: SSH_DIR)
      super()

      @ssh_dir = Pathname.new(ssh_dir)
    end

    def call
      # Create ~/.ssh if it doesn't exist
      ssh_dir.mkpath

      # Set correct permissions
      ssh_dir.chmod(0o700)

      servers = Server.all.to_a
      server_slugs = servers.map(&:slug)

      # Write private key, password, and known_hosts files
      servers.each do |server|
        if server.ssh_key.present?
          key_path = ssh_dir.join("#{server.slug}.pem")
          key_path.write(server.ssh_key)

          # Set correct permissions
          key_path.chmod(0o600)
        elsif server.password.present?
          pass_path = ssh_dir.join("#{server.slug}_password")
          pass_path.write(server.password)

          # Set correct permissions
          pass_path.chmod(0o600)
        end

        known_hosts_path = ssh_dir.join("#{server.slug}_known_hosts")

        if server.host_key.present?
          known_hosts_path.write("[#{server.host}]:#{server.port} #{server.host_key}\n")
        else
          known_hosts_path.write("")
        end

        known_hosts_path.chmod(0o600)
      end

      # Clean up orphan files
      ssh_dir.each_child do |path|
        basename = path.basename.to_s

        stem = if basename.end_with?(".pem")
                 basename.delete_suffix(".pem")
               elsif basename.end_with?("_password")
                 basename.delete_suffix("_password")
               elsif basename.end_with?("_known_hosts")
                 basename.delete_suffix("_known_hosts")
               else
                 next
               end

        next if server_slugs.include?(stem)

        path.delete
      end

      # Write config file
      lines = ["# Automatically generated by rsync-ui - DO NOT EDIT MANUALLY\n"]

      servers.each do |server|
        lines += [
          "Host #{server.slug}",
          "  HostName #{server.host}",
          "  Port #{server.port}",
          "  User #{server.username}",
          "  StrictHostKeyChecking yes",
          "  UserKnownHostsFile #{ssh_dir.join("#{server.slug}_known_hosts")}",
        ]

        if server.ssh_key.present?
          lines << "  IdentityFile #{ssh_dir.join("#{server.slug}.pem")}"
          lines << "  IdentitiesOnly yes"
        end

        lines << "\n"
      end

      # Atomically write config file
      file = ssh_dir.join("config.tmp")
      file.write(lines.join("\n"))
      file.chmod(0o600)

      File.rename(file, ssh_dir.join("config"))
    end
  end
end
```

- [ ] **Step 4: Run the full SSHConfigService spec**

```
docker compose exec app bundle exec rspec spec/services/servers/ssh_config_service_spec.rb -f documentation
```

Expected: all pass, including the existing tests (they now assert `StrictHostKeyChecking yes` instead of `no`). If existing tests assert `StrictHostKeyChecking no`, update them to `yes`.

- [ ] **Step 5: Run the full test suite**

```
docker compose exec app bundle exec rspec -f progress
```

Expected: all pass.

- [ ] **Step 6: Run RuboCop on changed Ruby files**

```
docker compose exec app bundle exec rubocop app/services/servers/ssh_config_service.rb app/services/servers/host_key_verification/capture_service.rb app/services/servers/fingerprint_service.rb app/controllers/servers_controller.rb app/models/server.rb
```

Fix any violations before committing.

- [ ] **Step 7: Commit**

```bash
git add app/services/servers/ssh_config_service.rb spec/services/servers/ssh_config_service_spec.rb
git commit -m "Write per-server known_hosts files and enable StrictHostKeyChecking"
```
