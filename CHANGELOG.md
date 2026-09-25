# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Removed

- Remove the "Sync SSH config" maintenance task, the SSH config is kept in sync automatically

### Security

- Only write SSH private keys to disk while a job is running, and pass SSH passwords through the environment instead of a file

## [v1.0.0-rc.1] - 2026-09-25

First release candidate.

[Unreleased]: https://github.com/floriandejonckheere/rsync-ui/compare/v1.0.0-rc.1..main
[v1.0.0-rc.1]: https://github.com/floriandejonckheere/rsync-ui/releases/tag/v1.0.0-rc.1
