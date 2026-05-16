# SSH improvements

Improve and streamline managing and using remote servers.

## Authenticity

Upon first connection to a remote server, the fingerprint of the server is stored in the local database.
It is displayed in the server.

- [ ] Add `fingerprint` column to the `server` table (string, nullable)
- [ ] Add `fingerprint` in the authentication card on the servers form
  - [ ] Empty before first connection
  - [ ] Displayed after first connection
  - [ ] Hint for the user: "Saved upon first connection"
- [ ] SSH service
  - [ ] If server has no fingerprint, save it
  - [ ] If server has a fingerprint, check if it matches the one saved (`Net::SSH` can do this)
  - [ ] Add specs for connecting to a server without a fingerprint, the server with a fingerprint, and a server with a different fingerprint. 

## Authentication

While `Net::SSH` can use both password and key authentication, if the `rsync` command is used it relies on the builtin SSH authentication.
The solution for this is to wrap any `rsync` calls in an `SSHService` that sets up an SSH connection using `Net::SSH`, and creates a master connection (`ControlMaster`, `ControlPath`), which can then be used by the `rsync` command (`rsync -e 'ssh -o ControlMaster=auto -o ControlPath=/tmp/ssh-%r@%h:%p' ...`).

This does not cover rsync daemon mode, which is out of scope.

## Audit log

Since we are currently using `rsync` to sync to remote servers, and `rsync` uses `ssh` under the hood, the rsync command executed remotely does not show up in the audit log.
To capture it, we'll need to instruct rsync to use `ssh -v` or an alternative verbose mode (shell?) that prints the command executed.
This will then be captured by the Rsync::ExecuteService and inserted into the audit log.
