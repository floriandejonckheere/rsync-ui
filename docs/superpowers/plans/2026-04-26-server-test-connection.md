# Server Test Connection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Test Connection" button to the server create/edit form that probes SSH reachability and shows a Turbo Stream notification without leaving the page.

**Architecture:** A `Servers::ConnectionService` wraps `Net::SSH` into a pure probe. A new `ServersController#connection` collection action resolves credentials (falling back to stored ones on edit), calls the service, and returns a Turbo Stream that prepends a notification into a persistent `#notifications` container in the layout. A Stimulus controller (`server-connection`) syncs main form field values into a secondary mini-form before Turbo submits it, and drives the button spinner via `turbo:submit-start`/`turbo:submit-end` events.

**Tech Stack:** Ruby/Rails 8, Net::SSH 7, Turbo Streams, Stimulus, ActionPolicy, RSpec

---

### Task 1: Servers::ConnectionService

**Files:**
- Create: `app/services/servers/connection_service.rb`
- Create: `spec/services/servers/connection_service_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/services/servers/connection_service_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Servers::ConnectionService do
  let(:host) { "example.com" }
  let(:port) { 22 }
  let(:username) { "admin" }
  let(:password) { "secret" }
  let(:ssh_key) { nil }
  let(:ssh_session) { instance_double(Net::SSH::Connection::Session) }

  before do
    allow(Net::SSH)
      .to receive(:start)
      .and_yield(ssh_session)

    allow(ssh_session)
      .to receive(:exec!)
      .and_return("ok\n")
  end

  describe "#call" do
    subject(:result) { described_class.call(host:, port:, username:, password:, ssh_key:) }

    it "returns success when SSH connection succeeds" do
      expect(result).to eq({ success: true })
    end

    it "runs 'echo ok' over SSH" do
      result

      expect(ssh_session).to have_received(:exec!).with("echo ok")
    end

    it "passes the correct SSH options" do
      result

      expect(Net::SSH).to have_received(:start).with(
        host, username,
        hash_including(
          port:,
          timeout: 10,
          non_interactive: true,
          verify_host_key: :never,
          password:,
          auth_methods: ["password"],
        ),
      )
    end

    context "when ssh_key is provided instead of password" do
      let(:password) { nil }
      let(:ssh_key) { "-----BEGIN OPENSSH PRIVATE KEY-----\nfake\n-----END OPENSSH PRIVATE KEY-----\n" }

      it "uses key_data and keys_only options" do
        result

        expect(Net::SSH).to have_received(:start).with(
          host, username,
          hash_including(key_data: [ssh_key], keys_only: true),
        )
      end

      it "does not pass password option" do
        result

        expect(Net::SSH).to have_received(:start).with(
          host, username,
          hash_not_including(:password),
        )
      end
    end

    context "when SSH authentication fails" do
      before do
        allow(Net::SSH)
          .to receive(:start)
          .and_raise(Net::SSH::AuthenticationFailed, "Authentication failed for admin@example.com")
      end

      it "returns failure with logs" do
        expect(result).to eq({
          success: false,
          logs: "Net::SSH::AuthenticationFailed: Authentication failed for admin@example.com",
        })
      end
    end

    context "when connection times out" do
      before do
        allow(Net::SSH)
          .to receive(:start)
          .and_raise(Net::SSH::ConnectionTimeout, "timed out")
      end

      it "returns failure with logs" do
        expect(result).to eq({
          success: false,
          logs: "Net::SSH::ConnectionTimeout: timed out",
        })
      end
    end

    context "when host is unreachable" do
      before do
        allow(Net::SSH)
          .to receive(:start)
          .and_raise(Errno::ECONNREFUSED, "Connection refused - connect(2) for example.com port 22")
      end

      it "returns failure with logs" do
        expect(result[:success]).to be false
        expect(result[:logs]).to include("Errno::ECONNREFUSED")
      end
    end
  end
end
```

- [ ] **Step 2: Run the spec to confirm it fails**

```bash
docker compose exec app bundle exec rspec spec/services/servers/connection_service_spec.rb
```

Expected: FAIL — `uninitialized constant Servers::ConnectionService`

- [ ] **Step 3: Implement the service**

Create `app/services/servers/connection_service.rb`:

```ruby
# frozen_string_literal: true

module Servers
  class ConnectionService < ApplicationService
    CONNECT_TIMEOUT = 10

    attr_reader :host, :port, :username, :password, :ssh_key

    def initialize(host:, port:, username:, password:, ssh_key:)
      super()

      @host = host
      @port = port
      @username = username
      @password = password
      @ssh_key = ssh_key
    end

    def call
      Net::SSH.start(host, username, ssh_options) do |ssh|
        ssh.exec!("echo ok")
      end

      { success: true }
    rescue StandardError => e
      { success: false, logs: "#{e.class}: #{e.message}" }
    end

    private

    def ssh_options
      opts = {
        port:,
        timeout: CONNECT_TIMEOUT,
        non_interactive: true,
        verify_host_key: :never,
      }

      if ssh_key.present?
        opts[:key_data] = [ssh_key]
        opts[:keys_only] = true
      elsif password.present?
        opts[:password] = password
        opts[:auth_methods] = ["password"]
      end

      opts
    end
  end
end
```

- [ ] **Step 4: Run the spec to confirm it passes**

```bash
docker compose exec app bundle exec rspec spec/services/servers/connection_service_spec.rb
```

Expected: All green.

- [ ] **Step 5: Run Rubocop on the new files**

```bash
docker compose exec app bundle exec rubocop app/services/servers/connection_service.rb spec/services/servers/connection_service_spec.rb
```

Expected: no offenses.

- [ ] **Step 6: Commit**

```bash
git add app/services/servers/connection_service.rb spec/services/servers/connection_service_spec.rb
git commit -m "Add Servers::ConnectionService for SSH connectivity probe"
```

---

### Task 2: ServerPolicy#connection?

**Files:**
- Modify: `app/policies/server_policy.rb`
- Modify: `spec/policies/server_policy_spec.rb`

- [ ] **Step 1: Write the failing specs**

Append the following `describe` block to `spec/policies/server_policy_spec.rb` (inside the `RSpec.describe` block, after the existing `describe "#destroy?"` block):

```ruby
  describe "#connection?" do
    it { is_expected.to be_connection }

    context "when user is another user" do
      let(:user) { other_user }

      it { is_expected.not_to be_connection }
    end

    context "when user is admin" do
      let(:user) { admin }

      it { is_expected.to be_connection }
    end

    context "when record is the Server class (new server form)" do
      let(:record) { Server }

      it { is_expected.to be_connection }
    end

    context "when record is the Server class and user is nil" do
      let(:record) { Server }
      let(:user) { nil }

      it { is_expected.not_to be_connection }
    end
  end
```

- [ ] **Step 2: Run the spec to confirm it fails**

```bash
docker compose exec app bundle exec rspec spec/policies/server_policy_spec.rb
```

Expected: FAIL — `undefined method 'be_connection'`

- [ ] **Step 3: Add `connection?` to the policy**

In `app/policies/server_policy.rb`, add `connection?` before the `private` keyword (there is no `private` — add it after the last `def destroy?` block):

```ruby
  def connection?
    return user.present? unless record.is_a?(Server)

    user.admin? || record.user == user
  end
```

Full file after the change:

```ruby
# frozen_string_literal: true

class ServerPolicy < ApplicationPolicy
  authorize :user

  scope_for :relation do |relation|
    next relation if user.admin?

    relation.where(user:)
  end

  def index?
    user.present?
  end

  def create?
    user.present?
  end

  def edit?
    user.admin? || record.user == user
  end

  def update?
    user.admin? || record.user == user
  end

  def destroy?
    user.admin? || record.user == user
  end

  def connection?
    return user.present? unless record.is_a?(Server)

    user.admin? || record.user == user
  end
end
```

- [ ] **Step 4: Run the spec to confirm it passes**

```bash
docker compose exec app bundle exec rspec spec/policies/server_policy_spec.rb
```

Expected: All green.

- [ ] **Step 5: Run Rubocop**

```bash
docker compose exec app bundle exec rubocop app/policies/server_policy.rb spec/policies/server_policy_spec.rb
```

Expected: no offenses.

- [ ] **Step 6: Commit**

```bash
git add app/policies/server_policy.rb spec/policies/server_policy_spec.rb
git commit -m "Add ServerPolicy#connection? for SSH connection test authorization"
```

---

### Task 3: Route, controller action, partial, and I18n

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/servers_controller.rb`
- Create: `app/views/servers/_connection_result.html.erb`
- Modify: `config/locales/en.yml`
- Modify: `spec/requests/servers_request_spec.rb`

- [ ] **Step 1: Write the failing request specs**

Append the following `describe` block to `spec/requests/servers_request_spec.rb` (inside the outer `RSpec.describe "Servers"` block, after the last `describe "DELETE /servers/:id"` block):

```ruby
  describe "POST /servers/connection" do
    let(:ssh_session) { instance_double(Net::SSH::Connection::Session) }

    before do
      allow(Net::SSH)
        .to receive(:start)
        .and_yield(ssh_session)
      allow(ssh_session)
        .to receive(:exec!)
        .and_return("ok\n")
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        post connection_servers_path, params: { host: "example.com", port: 22, username: "admin", password: "secret" }

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated (new server form, no server_id)" do
      before { sign_in user, scope: :user }

      it "returns a Turbo Stream response" do
        post connection_servers_path,
             params: { host: "example.com", port: 22, username: "admin", password: "secret" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end

      it "renders a success notification when SSH connects" do
        post connection_servers_path,
             params: { host: "example.com", port: 22, username: "admin", password: "secret" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to include(I18n.t("servers.connection.success"))
      end

      it "renders a failure notification when SSH fails" do
        allow(Net::SSH)
          .to receive(:start)
          .and_raise(Net::SSH::AuthenticationFailed, "Authentication failed")

        post connection_servers_path,
             params: { host: "example.com", port: 22, username: "admin", password: "wrong" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to include(I18n.t("servers.connection.failure"))
        expect(response.body).to include("Net::SSH::AuthenticationFailed")
      end
    end

    context "when authenticated (edit form, server_id provided)" do
      let(:server) { create(:server, :with_password, user:) }

      before { sign_in user, scope: :user }

      it "succeeds using submitted credentials when present" do
        post connection_servers_path,
             params: { server_id: server.id, host: server.host, port: server.port, username: server.username, password: "newpass" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to include(I18n.t("servers.connection.success"))
      end

      it "falls back to stored credentials when password and ssh_key params are blank" do
        post connection_servers_path,
             params: { server_id: server.id, host: server.host, port: server.port, username: server.username, password: "", ssh_key: "" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(Net::SSH).to have_received(:start).with(
          anything, anything,
          hash_including(password: server.password),
        )
        expect(response.body).to include(I18n.t("servers.connection.success"))
      end

      context "when server belongs to another user" do
        let(:server) { create(:server, :with_password, user: other_user) }

        it "returns forbidden" do
          post connection_servers_path,
               params: { server_id: server.id, host: server.host, port: server.port, username: server.username, password: "" },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end
```

- [ ] **Step 2: Run the spec to confirm it fails**

```bash
docker compose exec app bundle exec rspec spec/requests/servers_request_spec.rb -e "POST /servers/connection"
```

Expected: FAIL — `No route matches [POST] "/servers/connection"`

- [ ] **Step 3: Add the route**

In `config/routes.rb`, replace:

```ruby
  resources :servers
```

with:

```ruby
  resources :servers do
    collection do
      post :connection
    end
  end
```

- [ ] **Step 4: Update route annotations**

```bash
docker compose exec app bundle exec annotaterb routes
```

- [ ] **Step 5: Add the controller action**

In `app/controllers/servers_controller.rb`, add the `connection` action and a private `connection_params` method. Add the action before the `private` keyword, and add the helper method inside the `private` section.

Add the action after `destroy`:

```ruby
  def connection
    if params[:server_id].present?
      @server = Server.find(params[:server_id])
      authorize! @server, to: :connection?

      password = params[:password].presence || @server.password
      ssh_key  = params[:ssh_key].presence  || @server.ssh_key
    else
      authorize! Server, to: :connection?

      password = params[:password]
      ssh_key  = params[:ssh_key]
    end

    result = Servers::ConnectionService.call(
      host: params[:host],
      port: params[:port].to_i,
      username: params[:username],
      password:,
      ssh_key:,
    )

    render turbo_stream: turbo_stream.prepend(
      "notifications",
      partial: "servers/connection_result",
      locals: { result: },
    )
  end
```

- [ ] **Step 6: Create the Turbo Stream partial**

Create `app/views/servers/_connection_result.html.erb`:

```erb
<div
  role="alert"
  class="<%= alert_class_for(result[:success] ? :success : :alert) %> mb-4 shadow-lg"
  data-turbo-temporary
>
  <%= lucide_icon icon_name_for(result[:success] ? :success : :alert), class: "w-4 h-4" %>

  <h2>
    <%= result[:success] ? t("servers.connection.success") : t("servers.connection.failure") %>
  </h2>

  <% unless result[:success] %>
    <section>
      <pre class="text-xs whitespace-pre-wrap"><%= result[:logs] %></pre>
    </section>
  <% end %>
</div>
```

- [ ] **Step 7: Add I18n keys**

In `config/locales/en.yml`, inside the `servers:` block, add a `connection:` section. Find the existing `servers:` → `create:` entry and add `connection:` alongside it:

```yaml
    connection:
      success: Connection successful
      failure: Connection failed
```

Also add `test_connection:` under `servers:` → `form:`:

```yaml
      test_connection: Test connection
```

After editing, the relevant part of `en.yml` should look like:

```yaml
  servers:
    actions:
      ...
    connection:
      success: Connection successful
      failure: Connection failed
    create:
      success: Server was successfully created.
    ...
    form:
      ...
      test_connection: Test connection
      ...
```

- [ ] **Step 8: Normalize i18n files**

```bash
docker compose exec app bundle exec i18n-tasks normalize
```

- [ ] **Step 9: Run the request specs to confirm they pass**

```bash
docker compose exec app bundle exec rspec spec/requests/servers_request_spec.rb
```

Expected: All green.

- [ ] **Step 10: Format ERB**

```bash
docker compose exec app yarn herb:format
```

- [ ] **Step 11: Run Rubocop**

```bash
docker compose exec app bundle exec rubocop app/controllers/servers_controller.rb config/routes.rb
```

Expected: no offenses.

- [ ] **Step 12: Commit**

```bash
git add config/routes.rb app/controllers/servers_controller.rb \
        app/views/servers/_connection_result.html.erb \
        config/locales/en.yml \
        spec/requests/servers_request_spec.rb
git commit -m "Add ServersController#connection action with Turbo Stream response"
```

---

### Task 4: Persistent #notifications container in layout

**Files:**
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: Wrap the flash rendering in a persistent container**

In `app/views/layouts/application.html.erb`, find:

```erb
    <% if flash.any? { |_, msg| msg.present? } %>
      <%= render "shared/message", flash: flash %>
    <% end %>
```

Replace with:

```erb
    <div id="notifications">
      <% if flash.any? { |_, msg| msg.present? } %>
        <%= render "shared/message", flash: flash %>
      <% end %>
    </div>
```

- [ ] **Step 2: Run the full server request spec to check for regressions**

```bash
docker compose exec app bundle exec rspec spec/requests/servers_request_spec.rb
```

Expected: All green.

- [ ] **Step 3: Format ERB**

```bash
docker compose exec app yarn herb:format
```

- [ ] **Step 4: Commit**

```bash
git add app/views/layouts/application.html.erb
git commit -m "Add persistent #notifications container to layout for Turbo Stream targeting"
```

---

### Task 5: Stimulus controller and mini-form

**Files:**
- Create: `app/javascript/controllers/server_connection_controller.js`
- Modify: `app/javascript/controllers/index.js`
- Modify: `app/views/servers/_form.html.erb`

- [ ] **Step 1: Create the Stimulus controller**

Create `app/javascript/controllers/server_connection_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "icon", "spinner", "host", "port", "username", "password", "sshKey", "serverId"]
  static values = { sourceForm: String }

  connect() {
    this.element.addEventListener("turbo:submit-start", () => this.#setLoading(true))
    this.element.addEventListener("turbo:submit-end", () => this.#setLoading(false))
  }

  sync() {
    const form = document.getElementById(this.sourceFormValue)
    this.hostTarget.value = form.querySelector("[name='server[host]']").value
    this.portTarget.value = form.querySelector("[name='server[port]']").value
    this.usernameTarget.value = form.querySelector("[name='server[username]']").value
    this.passwordTarget.value = form.querySelector("[name='server[password]']").value
    this.sshKeyTarget.value = form.querySelector("[name='server[ssh_key]']").value
  }

  #setLoading(loading) {
    this.buttonTarget.disabled = loading
    this.iconTarget.classList.toggle("hidden", loading)
    this.spinnerTarget.classList.toggle("hidden", !loading)
  }
}
```

- [ ] **Step 2: Register the controller in index.js**

In `app/javascript/controllers/index.js`, add after the last `application.register` call:

```javascript
import ServerConnectionController from "./server_connection_controller"
application.register("server-connection", ServerConnectionController)
```

- [ ] **Step 3: Add the mini-form to the server form**

In `app/views/servers/_form.html.erb`, replace the entire `content_for :actions` block:

```erb
  <% content_for :actions do %>
    <button
      type="submit"
      form="server-form"
      class="btn-icon-outline btn-icon-lg"
      data-tooltip="<%= server.persisted? ? I18n.t("servers.form.submit_update") : I18n.t("servers.form.submit_create") %>"
    >
      <%= lucide_icon "check", class: "h-6 w-6" %>
    </button>
  <% end %>
```

with:

```erb
  <% content_for :actions do %>
    <%= form_with url: connection_servers_path,
                  method: :post,
                  data: {
                    turbo_stream: true,
                    controller: "server-connection",
                    "server-connection-source-form-value": "server-form",
                  } do |cf| %>
      <%= cf.hidden_field :server_id, value: server.persisted? ? server.id : nil,
                          data: { "server-connection-target": "serverId" } %>
      <%= cf.hidden_field :host,     data: { "server-connection-target": "host" } %>
      <%= cf.hidden_field :port,     data: { "server-connection-target": "port" } %>
      <%= cf.hidden_field :username, data: { "server-connection-target": "username" } %>
      <%= cf.hidden_field :password, data: { "server-connection-target": "password" } %>
      <%= cf.hidden_field :ssh_key,  data: { "server-connection-target": "sshKey" } %>

      <button
        type="submit"
        class="btn-icon-outline btn-icon-lg"
        data-server-connection-target="button"
        data-action="click->server-connection#sync"
        data-tooltip="<%= I18n.t("servers.form.test_connection") %>"
      >
        <%= lucide_icon "plug", class: "h-6 w-6",
                         data: { "server-connection-target": "icon" } %>
        <%= lucide_icon "loader-circle", class: "h-6 w-6 hidden animate-spin",
                         data: { "server-connection-target": "spinner" } %>
      </button>
    <% end %>

    <button
      type="submit"
      form="server-form"
      class="btn-icon-outline btn-icon-lg"
      data-tooltip="<%= server.persisted? ? I18n.t("servers.form.submit_update") : I18n.t("servers.form.submit_create") %>"
    >
      <%= lucide_icon "check", class: "h-6 w-6" %>
    </button>
  <% end %>
```

- [ ] **Step 4: Format ERB**

```bash
docker compose exec app yarn herb:format
```

- [ ] **Step 5: Run the full test suite for affected files**

```bash
docker compose exec app bundle exec rspec spec/requests/servers_request_spec.rb spec/services/servers/connection_service_spec.rb spec/policies/server_policy_spec.rb
```

Expected: All green.

- [ ] **Step 6: Commit**

```bash
git add app/javascript/controllers/server_connection_controller.js \
        app/javascript/controllers/index.js \
        app/views/servers/_form.html.erb
git commit -m "Add server connection Stimulus controller and test connection button"
```
