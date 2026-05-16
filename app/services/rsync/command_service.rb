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
        # Command
        rsync_path,

        # Flags
        *ssh_flags,
        *boolean_flags(BASIC_FLAGS),
        *boolean_flags(ADVANCED_FLAGS),
        *custom_argument_flags,
        *include_flags,
        *exclude_flags,

        # Source and destination paths
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
      # Only one server (source/destination) can be remote
      server = remote_server

      return [] unless server

      if server.ssh_key.present?
        # Authenticate using private key (via the SSH config file)
        ["-e \"ssh -F #{ssh_home}/config\""]
      else
        # Authenticate using password (via the non-interactive sshpass command)
        ["-e \"sshpass -f #{ssh_home}/#{server.slug}_password ssh -F #{ssh_home}/config\""]
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
        "#{repo.server.slug}:#{repo.path}"
      else
        repo.path
      end
    end
  end
end
