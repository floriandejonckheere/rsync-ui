# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Update net-ssh to 8.1.2
- Update Ruby to 4.0.10
- Update Bundler to 4.1.0
- Update Rails to 8.1.4.1
- Update action_policy to 0.7.8, connection_pool to 3.0.3, cuprite to 0.20.1, herb to 0.11.2, i18n-tasks to 1.2.1, irb to 1.19.0, minitest to 6.1.0, nokogiri to 1.19.7, prism to 2.1.0, rspec-rails to 8.1.0 (rspec-core 3.13.7, rspec-expectations 3.13.6, rspec-mocks 3.13.9, rspec-support 3.13.8) and solid_queue to 1.7.2
- Update tailwindcss and @tailwindcss/cli to 4.3.5, cronstrue to 3.39.0, and @herb-tools/formatter and @herb-tools/linter to 0.11.2
- Update JavaScript dependencies: @rails/actioncable 8.1.400, enhanced-resolve 5.26.0, postcss 8.5.32, postcss-import 17.0.1, postcss-selector-parser 7.1.7, resolve 1.22.13, tslib 2.9.1 and others
- Update apprise to 2.1.0
- Update ruby/setup-ruby to 1.343.0 and docker/login-action to 4.8.0 in CI
- Update Ruby dependencies: bootsnap 1.26.2, brakeman 8.1.1, ferrum 0.20.2, hashdiff 1.2.2, image_processing 2.2.1, pagy 43.8.5, parser 3.3.14.0, puma 8.1.2, rack 3.2.9, regexp_parser 2.13.4, rubocop 1.92.3, rubocop-ast 1.53.0, state_machines 0.305.0, state_machines-activemodel 0.300.0, state_machines-activerecord 0.304.0, thruster 0.1.28, webmock 3.36.0, websocket-driver 0.9.0 and websocket-extensions 0.2.0

## [v1.1.0] - 2026-11-02

### Changed

- Update Ruby to 4.0.9

### Added

- Publish the Docker image for both `linux/amd64` and `linux/arm64` (e.g. Apple Silicon, Raspberry Pi with a 64-bit OS)

## [v1.0.1] - 2026-10-20

### Fixed

- Install and configure sudo in the Docker image, so that jobs can run as superuser

## [v1.0.0] - 2026-10-08

### Added

- Optionally ping the server of the remote repository before starting a job, and cancel or abort the job run if it is unreachable
- Select the rsync version per job, or always use the latest one (default)
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

[Unreleased]: https://github.com/floriandejonckheere/rsync-ui/compare/v1.1.0..main
[v1.1.0]: https://github.com/floriandejonckheere/rsync-ui/compare/v1.0.1..v1.1.0
[v1.0.1]: https://github.com/floriandejonckheere/rsync-ui/compare/v1.0.0..v1.0.1
[v1.0.0]: https://github.com/floriandejonckheere/rsync-ui/compare/v1.0.0-rc.2..v1.0.0
[v1.0.0-rc.2]: https://github.com/floriandejonckheere/rsync-ui/compare/v1.0.0-rc.1..v1.0.0-rc.2
[v1.0.0-rc.1]: https://github.com/floriandejonckheere/rsync-ui/releases/tag/v1.0.0-rc.1
