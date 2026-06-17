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
      Rails.logger.info { "[#{job_run.id}] #{job_run.name} Executing job (hooks: #{hooks?}, streaming: #{streaming?})" }

      job_run.with_lock do
        return unless job_run.pending?

        # Transition to running
        job_run.start!
      end

      # Run pre-hook
      pre_hook_success = run_hook(job.pre_hook)
      return cancel if canceling?

      # Run rsync if pre-hook was successful
      if pre_hook_success
        rsync_success = run_rsync
        return cancel if canceling?
      end

      # Run post-hook if pre-hook was successful (regardless of rsync success or failure)
      if pre_hook_success
        post_hook_success = run_hook(job.post_hook)
        return cancel if canceling?
      end

      # Run success hook if pre-, rsync, and post-hook succeeded
      success_hook_success = if pre_hook_success && rsync_success && post_hook_success
                               run_hook(job.success_hook)
                             else
                               true
                             end

      # Run failure hook if pre-, rsync, post-, or success hook failed
      failure_hook_success = if pre_hook_success && rsync_success && post_hook_success && success_hook_success
                               true
                             else
                               run_hook(job.failure_hook)
                             end

      # Transition to final complete/failed status
      if pre_hook_success && rsync_success && post_hook_success && success_hook_success && failure_hook_success
        Rails.logger.info { "[#{job_run.id}] [#{job_run.name}] Completed job successfully" }
        job_run.complete!
      else
        Rails.logger.info { "[#{job_run.id}] [#{job_run.name}] Completed job with failure" }
        job_run.mark_failed!
      end
    rescue StandardError => e
      # Transition to errored, and save error class and message
      Rails.logger.error { "[#{job_run.id}] [#{job_run.name}] Completed job with error: #{e.class.name} #{e.message}" }
      Rails.logger.error { e.backtrace.map { "[#{job_run.id}] [#{job_run.name}] #{it}" }.join("\n") }

      job_run.error!(error_class: e.class.name, error_message: e.message) if job_run.pending? || job_run.running? || job_run.canceling?
    end

    private

    def run_rsync
      Rails.logger.debug { "[#{job_run.id}] [#{job_run.name}] Running command #{job_run.command.inspect}" }

      Tempfile.create(["job_run_#{job_run.name.parameterize(separator: '_')}_#{job_run.sequence}", ".log"]) do |file|
        last_status_line = nil

        begin
          result = Rsync::ExecuteService.new(job_run).call do |line|
            Rails.logger.debug { "[#{job_run.id}] [#{job_run.name}] #{line.chomp}" }

            status = Rsync::Progress.new(line) if job.opt_progress || job.opt_progress2

            if streaming?
              # Broadcast status or log line
              job_run.tick_status!(type: (status&.bytes ? "status" : "log"), content: line)
            end

            if job.opt_progress2 && status&.bytes
              # Update statistics on record
              job_run.tick_progress!(bytes_copied: status.bytes, progress: status.progress, speed: status.speed, remaining_time: status.remaining_time)

              last_status_line = line
            else
              file.write(line)
            end
          end

          # Write only the last status line to the log file
          file.write(last_status_line) if last_status_line

          # Upload complete log
          attach_log(file)

          exit_status = result.exit_status

          Rails.logger.debug { "[#{job_run.id}] [#{job_run.name}] Exited with exit status #{exit_status} and #{file.pos} bytes of output" }

          job_run.update!(exit_status: exit_status.exitstatus)

          exit_status.success?
        rescue StandardError
          # Upload complete log in case of error
          attach_log(file)

          raise
        end
      end
    end

    def run_hook(hook)
      return true unless hooks? && hook&.enabled?

      Rails.logger.debug { "[#{job_run.id}] [#{job_run.name}] Running #{hook.hook_type}-hook #{hook.id}" }

      Hooks::ExecuteService
        .new(hook, job_run:)
        .call
        .success
    end

    def canceling?
      job_run.reload.canceling?
    end

    def cancel
      Rails.logger.debug { "[#{job_run.id}] [#{job_run.name}] Cancelling job" }

      job_run.cancel!

      Rails.logger.debug { "[#{job_run.id}] [#{job_run.name}] Running failure hook #{job.failure_hook.id}" } if job.failure_hook
      run_hook(job.failure_hook)
    end

    def attach_log(file)
      return if job_run.output.attached?

      file.rewind
      job_run.output.attach(
        io: file,
        filename: "job_run_#{job_run.sequence}.log",
        content_type: "text/plain",
      )
    end

    def hooks?
      @hooks ||= Configuration.get("hooks")
    end

    def streaming?
      @streaming ||= Configuration.get("streaming")
    end
  end
end
