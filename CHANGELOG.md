# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Optionally ping the server of the remote repository before starting a job, and cancel or abort the job run if it is unreachable
- Select the rsync version per job
- Ship rsync 3.4.0 up to 3.5.1 side by side in the Docker image

### Changed

- Run jobs with the rsync binary of their selected rsync version, unless a custom local rsync path is set
- Make bulk edit page table headers sticky
- Only show custom SSH arguments in the remote shell option of the command preview

### Fixed

- Restore styling of the include/exclude pattern inputs

## [v1.0.0-rc.2] - 2026-09-27

### Added

- Automatically toggle `--delete` when toggling `--delete-{before,during,after}` and disable the mutually exclusive ones
- Automatically disable `--delete-{before,during,delay,after,excluded}` when disabling `--delete`
- Add a validation to make `--delete-{before,during,after,delay}` mutually exclusive
- Automatically enable and lock the options implied by `--archive` and `--append` in the job form
- Add a bulk edit page to compare and toggle the rsync options of all jobs at once

## [v1.0.0-rc.1] - 2026-09-25

First release candidate.

[Unreleased]: https://github.com/floriandejonckheere/rsync-ui/compare/v1.0.0-rc.2..main
[v1.0.0-rc.2]: https://github.com/floriandejonckheere/rsync-ui/compare/v1.0.0-rc.1..v1.0.0-rc.2
[v1.0.0-rc.1]: https://github.com/floriandejonckheere/rsync-ui/releases/tag/v1.0.0-rc.1
