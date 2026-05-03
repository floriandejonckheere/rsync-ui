# frozen_string_literal: true

module Hooks
  class ExecuteService < ApplicationService
    attr_reader :hook,
                :job_run

    def initialize(hook, job_run:)
      super()

      @hook = hook
      @job_run = job_run
    end

    def call
      full_command = [hook.command, interpolate(hook.arguments)]
        .compact_blank
        .join(" ")

      Tempfile.create(["hook_#{hook.hook_type}", ".log"]) do |file|
        exit_status = nil

        Open3.popen2e(full_command) do |_stdin, output, wait_thr|
          file.write(output.read)

          exit_status = wait_thr.value
        end

        file.rewind

        job_run.public_send(:"#{hook.hook_type}_hook_output").attach(
          io: file,
          filename: "hook_#{hook.hook_type}_#{job_run.sequence}.log",
          content_type: "text/plain",
        )

        { success: exit_status.success?, exit_status: exit_status.exitstatus, error: nil }
      end
    rescue StandardError => e
      { success: false, exit_status: nil, error: e.message }
    end

    private

    def interpolate(template)
      return nil if template.blank?

      job = job_run.job

      substitutions = {
        "{job_id}" => job.id,
        "{job_name}" => job.name,
        "{trigger}" => job_run.trigger,
        "{job_sequence}" => job_run.sequence.to_s,
        "{source_id}" => job.source_repository.id,
        "{source_name}" => job.source_repository.name,
        "{destination_id}" => job.destination_repository.id,
        "{destination_name}" => job.destination_repository.name,
        "{started_at}" => job_run.started_at&.iso8601,
        "{user_id}" => job_run.user.id,
        "{user_name}" => job_run.user.full_name,
        "{completed_at}" => job_run.completed_at&.iso8601,
        "{duration}" => job_run.duration&.to_s,
        "{status}" => job_run.status,
        "{error}" => ([job_run.error_class, job_run.error_messages].compact.join(": ") if job_run.error_class.present?),
      }

      template.gsub(/\{[^}]+\}/) { |match| substitutions.fetch(match, match) }
    end
  end
end
