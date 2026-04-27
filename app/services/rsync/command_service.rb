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
        "rsync",

        # Flags
        *ssh_flags,
        *boolean_flags(BASIC_FLAGS),
        *boolean_flags(ADVANCED_FLAGS),
        *rsync_path_flag,
        *custom_argument_flags,
        *include_flags,
        *exclude_flags,

        # Mandatory flags
        "--info=progress2", # Show total progress
        "--no-inc-recursive", # Compute total files to transfer upfront

        # Source and destination paths
        source_path,
        destination_path,
      ].compact.join(" ")
    end

    private

    def boolean_flags(map)
      map.filter_map { |attr, flag| flag if job.public_send(attr) }
    end

    def ssh_flags
      port = non_standard_port
      return [] unless port

      ["-e \"ssh -p #{port}\""]
    end

    def rsync_path_flag
      path =
        if job.opt_superuser && job.opt_rsync_path.present?
          "sudo #{job.opt_rsync_path}"
        elsif job.opt_superuser
          "sudo rsync"
        elsif job.opt_rsync_path.present?
          job.opt_rsync_path
        end

      path ? ["--rsync-path=\"#{path}\""] : []
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

    def non_standard_port
      [job.source_repository, job.destination_repository]
        .compact
        .select(&:remote?)
        .filter_map { |repo| repo.server&.port }
        .find { |port| port != 22 }
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
        "#{repo.server.username}@#{repo.server.host}:#{repo.path}"
      else
        repo.path
      end
    end
  end
end
