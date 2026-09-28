# frozen_string_literal: true

# A set of recommended rsync options for a specific use case.
# Applying a preset resets all toggleable options to their defaults, enables the
# preset's options, and replaces the custom rsync arguments. Additive presets
# only enable the preset's options, and leave the other options untouched.
class JobPreset
  PRESETS = {
    "borg" => {
      options: [
        :opt_archive,
        :opt_delete,
        :opt_delete_after,
        :opt_numeric_ids,
        :opt_hard_links,
        :opt_one_file_system,
        :opt_partial,
      ],
      arguments: "--whole-file --sparse",
    },
    "mirror" => {
      options: [
        :opt_archive,
        :opt_delete,
        :opt_delete_after,
        :opt_numeric_ids,
        :opt_hard_links,
        :opt_acls,
        :opt_xattrs,
        :opt_one_file_system,
        :opt_partial,
      ],
      arguments: nil,
    },
    "archive" => {
      options: [
        :opt_archive,
        :opt_hard_links,
        :opt_partial,
      ],
      arguments: nil,
    },
    "slow_network" => {
      options: [
        :opt_archive,
        :opt_delete,
        :opt_delete_after,
        :opt_compress,
        :opt_partial,
      ],
      arguments: "--timeout=300",
    },
    "restic" => {
      # Restic files are content-addressed and never modified, so existing files can be skipped.
      # Partial files are not kept, as they would never be completed when skipping existing files.
      options: [
        :opt_archive,
        :opt_delete,
        :opt_delete_after,
        :opt_ignore_existing,
        :opt_numeric_ids,
        :opt_one_file_system,
      ],
      arguments: "--whole-file",
    },
    "large_files" => {
      options: [
        :opt_archive,
        :opt_delete,
        :opt_delete_after,
        :opt_inplace,
        :opt_numeric_ids,
      ],
      arguments: "--sparse",
    },
    "versions" => {
      # Without --backup-dir, rsync protects the backup files (suffixed with ~) from deletion
      options: [
        :opt_archive,
        :opt_delete,
        :opt_delete_after,
        :opt_backup,
      ],
      arguments: nil,
    },
    "trial_run" => {
      options: [
        :opt_dry_run,
        :opt_itemize_changes,
      ],
      arguments: nil,
      additive: true,
    },
  }.freeze

  attr_reader :key,
              :options,
              :arguments

  def self.all
    PRESETS.map { |key, preset| new(key:, **preset) }
  end

  def self.find(key)
    all.find { |preset| preset.key == key }
  end

  def self.keys
    PRESETS.keys
  end

  def initialize(key:, options:, arguments:, additive: false)
    @key = key
    @options = options
    @arguments = arguments
    @additive = additive
  end

  def additive? = @additive

  def name
    I18n.t(:name, scope: [:job_presets, key])
  end

  def description
    I18n.t(:description, scope: [:job_presets, key])
  end

  # Attributes to assign to a job to apply the preset
  def attributes
    return options.index_with(true) if additive?

    Job::TOGGLEABLE_OPTIONS
      .index_with { |option| options.include?(option) || Job.column_defaults.fetch(option.to_s) }
      .merge(opt_arguments: arguments)
  end
end
