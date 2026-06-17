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
      command = [hook.command, interpolate(hook.arguments)]
        .compact_blank
        .join(" ")

      Rails.logger.debug { "[#{job_run.id}] [#{hook.id}] Running command #{command.inspect}" }

      Tempfile.create(["hook_#{hook.hook_type}", ".log"]) do |file|
        exit_status = run(command, file)

        Rails.logger.debug { "[#{job_run.id}] [#{hook.id}] Exited with exit status #{exit_status.exitstatus} and #{file.pos} bytes of output" }

        attach_output(file)

        persist_status(
          status: exit_status.success? ? "success" : "failed",
          exit_status: exit_status.exitstatus,
        )

        ExecutionResult.new(success: exit_status.success?, exit_status: exit_status.exitstatus)
      rescue StandardError => e
        Rails.logger.error { "[#{job_run.id}] [#{hook.id}] Exited with error #{e.class.name} #{e.message} and #{file.pos} bytes of output" }
        Rails.logger.error { e.backtrace.map { "[#{job_run.id}] [#{hook.id}] #{it}" }.join("\n") }

        attach_output(file)

        persist_status(status: "errored", error_class: e.class.name, error_message: e.message)

        ExecutionResult.new(success: false, exit_status: nil)
      end
    end

    private

    def run(command, file)
      Timeout.timeout(timeout.in_seconds) do
        Open3.popen2e(command, pgroup: true) do |_stdin, output, wait_thr|
          job_run.update!(pid: wait_thr.pid)

          file.write(output.read)

          wait_thr.value
        end
      end
    rescue Timeout::Error
      Rails.logger.debug { "[#{job_run.id}] [#{hook.id}] Timed out after #{timeout.inspect}" }

      raise Timeout::Error, "execution expired after #{timeout.inspect}"
    ensure
      job_run.update_column(:pid, nil) if job_run.persisted? # rubocop:disable Rails/SkipsModelValidations
    end

    def attach_output(file)
      attachment = job_run.public_send(:"#{hook.hook_type}_hook_output")
      return if attachment.attached?

      file.rewind
      attachment.attach(
        io: file,
        filename: "hook_#{hook.hook_type}_#{job_run.sequence}.log",
        content_type: "text/plain",
      )
    rescue StandardError
      nil
    end

    def persist_status(status:, exit_status: nil, error_class: nil, error_message: nil)
      job_run.update!(
        "#{hook.hook_type}_hook_status": status,
        "#{hook.hook_type}_hook_exit_status": exit_status,
        "#{hook.hook_type}_hook_error_class": error_class,
        "#{hook.hook_type}_hook_error_message": error_message,
      )
    end

    def interpolate(template)
      return if template.blank?

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
        "{error}" => ([job_run.error_class, job_run.error_message].compact.join(": ") if job_run.error_class.present?),
      }

      template.gsub(/\{[^}]+\}/) { |match| substitutions.fetch(match, match) }
    end

    def timeout
      Configuration.get("hooks.timeout").minutes
    end
  end
end
