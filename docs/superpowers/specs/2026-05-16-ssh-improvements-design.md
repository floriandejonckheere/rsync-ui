# SSH Improvements Design

**Date:** 2026-05-16
**Scope:** Authenticity (fingerprint verification) and Authentication (SSH config file for rsync)
**Out of scope:** Audit log for remote rsync commands, ControlMaster optimisation, replacing Net::SSH with native ssh wrapper

---

## Section 1: Authenticity

### Goal

Prevent connections to servers whose host key has changed. The user must explicitly fetch and store a server's fingerprint before any SSH connection is allowed.

### Database

Add a nullable `fingerprint` string column to the `servers` table. No default value. No index required.

### Model

Add format validation to `Server`:

```ruby
validates :fingerprint,
          format: { with: /\ASHA256:[A-Za-z0-9+\/=]{43}\z/ },
          allow_blank: true
```

Accepts the standard `SHA256:<base64>` format produced by `Net::SSH` and OpenSSH.

### Form

Add a **Fingerprint** field to the authentication card of the servers form, always visible regardless of auth type. Beside it, a small "Fetch" button fires a `POST /servers/:id/fingerprint` Turbo Stream request (same pattern as "Test connection") and populates the field with the returned value via a Stimulus controller. Hint text: "Verified on every connection" (I18n key: `servers.form.fingerprint_hint`).

### New endpoint: `POST /servers/:id/fingerprint`

Calls `Servers::FingerprintService`. Returns a Turbo Stream that sets the fingerprint input field value, or an error message on failure (unreachable host, auth failure).

### `Servers::FingerprintService`

Subclasses `Servers::SSHService`. Overrides `ssh_options` to use `verify_host_key: :never` and captures the fingerprint via the Net::SSH `verify_host_key` callback (the callback receives the host key object; call `.fingerprint` on it). Returns `{ fingerprint: "SHA256:..." }`. Always connects regardless of whether a fingerprint is stored.

### `Servers::SSHService` — host key verification

Replace `verify_host_key: :never` with a lambda verifier:

```ruby
verify_host_key: ->(host_key) {
  raise Net::SSH::HostKeyMismatch if server.fingerprint.blank?
  raise Net::SSH::HostKeyMismatch unless server.fingerprint == host_key.fingerprint
  
  true
}
```

All subclasses (`ConnectionService`, `ResourceUsageService`, etc.) inherit this automatically. `FingerprintService` overrides it back to `:never`.

### Specs

- `Server` model: fingerprint format validation (valid SHA256, invalid format, blank allowed).
- `Servers::FingerprintService`: returns fingerprint, connects regardless of stored value.
- `Servers::SSHService`: raises `Net::SSH::HostKeyMismatch` when fingerprint is blank, raises on mismatch, succeeds on match.
- `Servers::ConnectionService`: succeeds with matching fingerprint, fails with mismatched fingerprint.
- `NetSSHHelpers#stub_ssh`: extend with optional `fingerprint:` kwarg that configures the host key double.

---

## Section 2: Authentication

### Goal

`rsync` relies on the system SSH binary for transport and cannot use Net::SSH's in-process authentication. A managed `~/.ssh/config` + per-server key files allows `rsync` to authenticate (both key and password) without user interaction.

### SSH key files

Each key-auth server's private key is written to `~/.ssh/<server_uuid>` with permissions `0600`. No key file is written for password-auth servers. Orphaned key files (server deleted) are cleaned up by `Servers::SshConfigService`.

### `~/.ssh/config` format

The service regenerates the entire file atomically (write to tempfile, then `File.rename`). Permissions: `0600`.

```
# Managed by rsync-ui — do not edit manually

Host <server_uuid>
  HostName <host>
  Port <port>
  User <username>
  StrictHostKeyChecking yes
  UserKnownHostsFile /dev/null
  IdentityFile ~/.ssh/<server_uuid>
  IdentitiesOnly yes

Host <password_server_uuid>
  HostName <host>
  Port <port>
  User <username>
  StrictHostKeyChecking yes
  UserKnownHostsFile /dev/null
  ProxyCommand sshpass -p '<password>' nc %h %p
```

`StrictHostKeyChecking yes` + `UserKnownHostsFile /dev/null` ensures the system SSH binary never performs its own host key verification — fingerprint checking is handled exclusively by `Net::SSH` in `Servers::SSHService`.

### `Servers::SshConfigService`

A plain service (not a subclass of `SSHService`). On every call:

1. Iterates all `Server` records (machine-scoped, all users).
2. Writes each key-auth server's private key to `~/.ssh/<server_uuid>` (`0600`).
3. Deletes any `~/.ssh/<uuid>` files whose UUID no longer matches a server record.
4. Renders the full config string and atomically writes `~/.ssh/config` (`0600`).

Idempotent — safe to call multiple times with the same data.

### `Servers::SyncSshConfigJob`

Calls `Servers::SshConfigService.call`. Enqueued (no delay) via `Server` callbacks:

```ruby
after_create_commit :sync_ssh_config
after_update_commit :sync_ssh_config
after_destroy_commit :sync_ssh_config

...

def sync_ssh_config
  Servers::SyncSshConfigJob.perform_later
end
```

Also invoked on container startup via an initializer, or via a Rake task to ensure the config is in sync after a deploy.

### `Rsync::CommandService` changes

- `ssh_flags` currently emits `-e "ssh -p <port>"` for non-standard ports. Replace with `-e "ssh -F ~/.ssh/config"` whenever a remote server is present (port is now resolved by the SSH config).
- `repository_path` for remote repos changes from `<username>@<host>:<path>` to `<server_uuid>:<path>` — the SSH config maps UUID → HostName/Port/User.

### sshpass

Add `sshpass` and `netcat` (`nc`) to the Dockerfile (`apt-get install -y sshpass netcat-openbsd`). Document under prerequisites in `docs/COMMANDS.md`. `nc` is used in the `ProxyCommand` for password-auth servers to open the TCP connection that sshpass then authenticates over.

### Specs

- `Servers::SshConfigService`: correct config generated for key-auth server; correct ProxyCommand generated for password-auth server; mixed fleet; orphaned key files cleaned up; idempotent.
- `Servers::SyncSshConfigJob`: enqueued after server create, update, and destroy.
- `Rsync::CommandService`: remote path uses server UUID; `-e "ssh -F ~/.ssh/config"` emitted when remote server present; no `-e` flag for local-only jobs.
