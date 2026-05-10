# Server Test Connection — Design Spec

**Date:** 2026-04-26

## Overview

Add a "Test Connection" button to the server create/edit form. Clicking it tests whether the server is reachable over SSH using the current form values, then shows a success or failure notification without leaving the page.

## Route

```
POST /servers/connection
```

Added as a collection action on the existing `servers` resource:

```ruby
resources :servers do
  collection do
    post :connection
  end
end
```

Route helper: `connection_servers_path`

## Controller

New `ServersController#connection` action.

**Authorization:**
- If `server_id` param is present: find the server (scoped to current user via `authorized_scope`), then `authorize! @server, to: :connection?`.
- If no `server_id`: `authorize! Server, to: :connection?` (class-level, any authenticated user).

**Credential resolution:**
- If `server_id` is present and `password`/`ssh_key` params are blank, use the stored credentials from the found server record.
- Otherwise use the submitted params directly.

**Response:** Always `text/vnd.turbo-stream.html`. Calls `Servers::ConnectionService` and renders a Turbo Stream that prepends a notification into `#notifications`.

## Service

`Servers::ConnectionService`

Accepts a plain struct/hash of resolved connection params: `host`, `port`, `username`, `password`, `ssh_key`.

Uses `Net::SSH` with the same options as `ResourceUsageService` (10s timeout, `non_interactive: true`, `verify_host_key: :never`). Runs `echo ok` and closes the session.

Returns:
- `{ success: true }` on success
- `{ success: false, logs: "<ExceptionClass>: <message>" }` on any exception

Does **not** persist anything — pure connectivity probe.

## Policy

Add `connection?` to `ServerPolicy` for both record-level and class-level:

```ruby
def connection?
  user.admin? || record.user == user
end

# Class-level: any authenticated user may probe before saving
def self.connection?
  user.present?
end
```

## Layout Change

Wrap the existing flash rendering in `application.html.erb` inside a persistent container:

```html
<div id="notifications">
  <% if flash.any? { |_, msg| msg.present? } %>
    <%= render "shared/message", flash: flash %>
  <% end %>
</div>
```

The container is always present (even when empty) so the Turbo Stream can target it regardless of page state.

## Turbo Stream Response

The controller renders a partial `servers/_connection_result` as a Turbo Stream:

```erb
<%= turbo_stream.prepend "notifications" do %>
  <div role="alert" class="<%= result[:success] ? alert_class_for(:notice) : alert_class_for(:alert) %> mb-4 shadow-lg" data-turbo-temporary>
    <%= lucide_icon result[:success] ? "check-circle" : "x-circle", class: "w-4 h-4" %>
    <h2><%= result[:success] ? t("servers.connection.success") : t("servers.connection.failure") %></h2>
    <% unless result[:success] %>
      <section><pre class="text-xs whitespace-pre-wrap"><%= result[:logs] %></pre></section>
    <% end %>
  </div>
<% end %>
```

`data-turbo-temporary` ensures Turbo removes the notification on the next navigation.

## Mini-Form and Stimulus Controller

### Form (inside `content_for :actions` in `_form.html.erb`)

A secondary form targeting `POST /servers/connection`, marked `data-turbo-stream`, with hidden inputs for `host`, `port`, `username`, `password`, `ssh_key`, and optionally `server_id`. Because the form uses `form_with url:` (not model-based), all param names are **unnamespaced** (`host`, `port`, …) — the controller reads them as `params[:host]`, `params[:server_id]`, etc. The Stimulus controller populates the hidden inputs by reading from the main form's namespaced fields (`server[host]`, `server[port]`, …) before submission.

```erb
<%= form_with url: connection_servers_path,
              method: :post,
              data: {
                turbo_stream: true,
                controller: "server-connection",
                "server-connection-source-form-value": "server-form"
              } do |f| %>
  <%= f.hidden_field :server_id, value: server.persisted? ? server.id : nil,
                     data: { "server-connection-target": "serverId" } %>
  <%= f.hidden_field :host,     data: { "server-connection-target": "host" } %>
  <%= f.hidden_field :port,     data: { "server-connection-target": "port" } %>
  <%= f.hidden_field :username, data: { "server-connection-target": "username" } %>
  <%= f.hidden_field :password, data: { "server-connection-target": "password" } %>
  <%= f.hidden_field :ssh_key,  data: { "server-connection-target": "sshKey" } %>

  <button
    type="submit"
    class="btn-icon-outline btn-icon-lg"
    data-server-connection-target="button"
    data-action="click->server-connection#sync"
    data-tooltip="<%= I18n.t('servers.form.connection') %>"
  >
    <%= lucide_icon "plug", class: "h-6 w-6", data: { "server-connection-target": "icon" } %>
    <%= lucide_icon "loader-circle", class: "h-6 w-6 hidden animate-spin", data: { "server-connection-target": "spinner" } %>
  </button>
<% end %>
```

### Stimulus Controller (`server_connection_test_controller.js`)

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "icon", "spinner", "host", "port", "username", "password", "sshKey", "serverId"]
  static values = { sourceForm: String }

  sync() {
    const form = document.getElementById(this.sourceFormValue)
    this.hostTarget.value     = form.querySelector("[name='server[host]']").value
    this.portTarget.value     = form.querySelector("[name='server[port]']").value
    this.usernameTarget.value = form.querySelector("[name='server[username]']").value
    this.passwordTarget.value = form.querySelector("[name='server[password]']").value
    this.sshKeyTarget.value   = form.querySelector("[name='server[ssh_key]']").value
  }

  connect() {
    this.element.addEventListener("turbo:submit-start", () => this.#setLoading(true))
    this.element.addEventListener("turbo:submit-end",   () => this.#setLoading(false))
  }

  #setLoading(loading) {
    this.buttonTarget.disabled = loading
    this.iconTarget.classList.toggle("hidden", loading)
    this.spinnerTarget.classList.toggle("hidden", !loading)
  }
}
```

`sync` fires before submission (via `data-action="click->server-connection#sync"`), copying the current field values into the hidden inputs. The `turbo:submit-start`/`turbo:submit-end` events on the form element drive the spinner state.

## I18n Keys

```yaml
en:
  servers:
    form:
      connection: Test connection
    connection:
      success: Connection successful
      failure: Connection failed
```

## Error Handling

- Network/auth errors from Net::SSH are caught and returned as `logs`.
- A 10-second connect timeout prevents the button from hanging indefinitely.
- If the server is not found (e.g., stale `server_id`), the controller returns a 404 before touching the service.

## Testing

- `Servers::ConnectionService` — unit tests with mocked `Net::SSH.start`: success path, auth failure, connection timeout, host unreachable.
- `ServersController#connection` — request specs: success (mocked service), failure (mocked service), unauthorized access, missing server_id on new server form, fallback to stored credentials.
- No system/browser tests required for the spinner state; the Turbo Stream integration is covered by the request specs asserting the stream response.
