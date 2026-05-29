# frozen_string_literal: true

module JobRuns
  class ExecuteService < ApplicationService
    attr_reader :job_run,
                :job

    def initialize(job_run)
      super()

      @job_run = job_run
      @job = job_run.job
    end

    def call
      started = false
      job_run.with_lock do
        if job_run.reload.pending?
          job_run.start!

          started = true
        end
      end

      return unless started

      Rails.logger.info "[#{job.id}] Executing job #{job.name}"

      pre_hook_success = run_hook(job.pre_hook)
      return finalize_cancel if canceling?

      rsync_success = pre_hook_success ? run_rsync : nil
      return finalize_cancel if canceling?

      post_hook_success = pre_hook_success ? run_hook(job.post_hook) : nil
      return finalize_cancel if canceling?

      if pre_hook_success && rsync_success && post_hook_success
        job_run.complete!

        run_hook(job.success_hook) if hooks?
      else
        job_run.mark_failed!

        run_hook(job.failure_hook) if hooks?
      end
    rescue StandardError => e
      # rsync's own log is attached inside run_rsync (both happy path and its
      # rescue clause), and each hook attaches its own log. Nothing to salvage.
      job_run.error!(error_class: e.class.name, error_message: e.message) if job_run.running? || job_run.canceling?
    end

    private

    def run_rsync
      command = Rsync::CommandService
        .new(job:)
        .call

      Tempfile.create(["job_run_#{job.name.parameterize(separator: '_')}_#{job_run.sequence}", ".log"]) do |file|
        file.write("#{command}\n")

        last_status_line = nil

        begin
          result = Rsync::ExecuteService.new(command, job_run).call do |line|
            status = Rsync::Progress.new(line) if job.opt_progress || job.opt_progress2

            if streaming?
              payload = { type: status&.bytes ? "status" : "log", content: line }

              ActionCable.server.broadcast("job_run_logs_#{job_run.id}", payload)
            end

            if job.opt_progress2 && status&.bytes
              job_run.tick!(bytes_copied: status.bytes, progress: status.progress, speed: status.speed, remaining_time: status.remaining_time)

              last_status_line = line
            else
              file.write(line)
            end
          end

          file.write(last_status_line) if last_status_line

          attach_rsync_log(file)

          exit_status = result.exit_status

          Rails.logger.info { "[#{job.id}] rsync exited: #{exit_status.exitstatus || "signal #{exit_status.termsig}"}" }

          exit_status.success?
        rescue StandardError
          attach_rsync_log(file)

          raise
        end
      end
    end

    def run_hook(hook)
      return true unless hooks? && hook&.enabled?

      Hooks::ExecuteService
        .new(hook, job_run:)
        .call
        .success
    end

    def canceling?
      job_run.reload.canceling?
    end

    def finalize_cancel
      job_run.cancel!

      run_hook(job.failure_hook) if hooks? # cancellation routes to failure-hook semantics
    end

    def attach_rsync_log(file)
      return if job_run.output.attached?

      file.rewind
      job_run.output.attach(
        io: file,
        filename: "job_run_#{job_run.sequence}.log",
        content_type: "text/plain",
      )
    rescue StandardError
      nil
    end

    def hooks?
      @hooks ||= Configuration.get("hooks")
    end

    def streaming?
      @streaming ||= Configuration.get("streaming")
    end
  end
end
