# Design: Host Key Storage for Strict SSH Verification

**Date:** 2026-05-17
**Status:** Approved

## Problem

`SSHConfigService` currently writes `StrictHostKeyChecking no` and `UserKnownHostsFile /dev/null` for every server in the generated SSH config. This disables MITM protection for all rsync operations. The `Server` model already stores a `fingerprint` for use in programmatic `Net::SSH` connections, but the SSH config file (used by rsync) has no equivalent protection.

## Goal

Enable strict SSH host key verification for rsync by storing the server's full public host key and writing per-server `known_hosts` files.

## Design Decisions

- Store the full OpenSSH public host key in a new `host_key` column alongside the existing `fingerprint` column.
- Both fields are written together at fetch time (via the existing "fetch fingerprint" button) and are read-only for the user — not editable via the form.
- If no `host_key` is stored, write an empty known_hosts file so rsync fails (fail-closed, no silent fallback to insecure mode).
- The fingerprint display in the form remains as-is (read-only, shown after fetch).

## Components

### Database

- Add `host_key` (text, nullable) column to `servers`.
- Existing `fingerprint` (string, nullable) column is unchanged.

### Model (`Server`)

- Add `host_key` attribute with format validation: must match one of `ssh-rsa`, `ssh-ed25519`, `ecdsa-sha2-nistp256`, `ecdsa-sha2-nistp384`, `ecdsa-sha2-nistp521` key types, `allow_blank: true`.
- `fingerprint` validation unchanged.
- Neither `fingerprint` nor `host_key` are included in user-editable strong params — the fetch flow is the sole write path.

### `HostKeyVerification::CaptureService`

- Currently captures `options[:fingerprint]`.
- Extended to also capture `options[:key]` and expose a `host_key` reader returning `"#{key.ssh_type} #{Base64.strict_encode64(key.to_blob)}"`.

### `FingerprintService`

- Extended to return `{ success: true, host_key: "...", fingerprint: "SHA256:..." }`.

### `ServersController#fingerprint`

- Saves both `host_key` and `fingerprint` to the server record after a successful fetch.
- The Turbo Stream response updates the fingerprint display (unchanged) and the hidden `host_key` field.

### `HostKeyVerification::VerifyService`

- Unchanged — still compares `server.fingerprint == options[:fingerprint]`.

### `SSHConfigService`

For each server, writes a dedicated known_hosts file at `~/.ssh/<slug>_known_hosts`:

- **`host_key` present** → one line: `[host]:port key_type base64_blob`
- **`host_key` absent** → empty file (rsync connection fails with host key error)

SSH config block changes:

```
# Before
StrictHostKeyChecking no
UserKnownHostsFile /dev/null

# After
StrictHostKeyChecking yes
UserKnownHostsFile ~/.ssh/<slug>_known_hosts
```

Orphaned `_known_hosts` files are cleaned up in the same pass as `.pem` and `_password` files.

### Form & JavaScript

- `_fingerprint.html.erb` partial: fingerprint display remains read-only; a hidden field carries `server[host_key]` so the fetch response can update it via Turbo Stream.
- `server_fingerprint_controller.js`: updated to write the returned `host_key` into the hidden field in addition to updating the fingerprint display.

## Error Handling

- If `host_key` is blank when `SSHConfigService` runs, an empty known_hosts file is written. rsync will fail with a host key verification error, which surfaces to the user as a job failure — intentional fail-closed behaviour.
- The fetch flow already handles connection failures and displays errors in the UI.

## Testing

- Unit test `CaptureService` captures `host_key` correctly from a mock Net::SSH options hash.
- Unit test `SSHConfigService` writes correct known_hosts content when `host_key` is present, and an empty file when absent.
- Unit test `Server` model validates `host_key` format.
- Integration/request spec for `ServersController#fingerprint` verifies both fields are saved.
