# frozen_string_literal: true

module JobRuns
  class ExecuteService < ApplicationService
    attr_reader :job_run,
                :job,
                :trigger

    def initialize(job_run)
      super()

      @job_run = job_run
      @job = job_run.job
      @trigger = job_run.trigger
    end

    def call
      return unless job_run.pending?

      Rails.logger.info "[#{job.id}] Executing job #{job.name}"

      job_run.start!

      enqueue_notifications(job_run, "start")

      # Pre-hook: halt execution if it fails
      if Configuration.get("hooks")
        hook = job.pre_hook

        if hook&.enabled?
          result = Hooks::ExecuteService
            .new(hook, job_run:)
            .call

          unless result[:success]
            if result[:canceled]
              job_run.cancel!
            else
              job_run.error!(error_message: "Pre-hook failed (exit #{result[:exit_status]}): #{result[:error]}")

              enqueue_notifications(job_run, "failure")
            end

            return
          end
        end
      end

      command = Rsync::CommandService
        .new(job:)
        .call

      Tempfile.create(["job_run_#{job.name.parameterize(separator: '_')}_#{job_run.sequence}", ".log"]) do |file|
        Rails.logger.info { "[#{job.id}] Executing command: #{command}" }

        # Write full command to the log file
        file.write("#{command}\n")

        # Capture last status line
        last_status_line = nil

        result = Rsync::ExecuteService.new(command, job_run).call do |line|
          # Parse status line if --progress or --info=progress2 is enabled
          status = Rsync::Progress.new(line) if job.opt_progress || job.opt_progress2

          # Broadcast log line
          ActionCable.server.broadcast("job_run_logs_#{job_run.id}", { type: status&.bytes ? "status" : "log", content: line }) if Configuration.get("streaming")

          if job.opt_progress2 && status&.bytes
            job_run.tick!(bytes_copied: status.bytes, progress: status.progress, speed: status.speed, remaining_time: status.remaining_time)

            last_status_line = line
          else
            file.write(line)
          end
        end

        # Write last status line to the log file
        file.write(last_status_line) if last_status_line

        file.rewind

        job_run.output.attach(
          io: file,
          filename: "job_run_#{job_run.sequence}.log",
          content_type: "text/plain",
        )

        exit_status = result.exit_status

        Rails.logger.info { "[#{job.id}] Command exited with status: #{exit_status.exitstatus || "signal #{exit_status.termsig}"}" }

        # Mark job as canceled if cancellation was requested
        next job_run.cancel! if result.canceled

        # Mark job as completed or failed based on the exit status
        exit_status.success? ? job_run.complete! : job_run.mark_failed!

        # Post-hook: always runs after rsync (success or failure)
        execute_optional_hook(job_run, "post")

        # Success/failure hooks: only run if rsync succeeded or failed
        execute_optional_hook(job_run, exit_status.success? ? "success" : "failure")

        # Send notifications
        enqueue_notifications(job_run, exit_status.success? ? "success" : "failure")
      rescue SignalException => e
        # Worker process received a signal (e.g. SIGTERM on shutdown). Attach
        # whatever was captured before re-raising so logs are not lost.
        attach_log(job_run, file)

        job_run.error!(error_class: e.class.name, error_message: e.message) if job_run.running?

        enqueue_notifications(job_run, "failure")

        raise
      rescue StandardError => e
        attach_log(job_run, file)

        job_run.error!(error_class: e.class.name, error_message: e.message) if job_run.running?

        enqueue_notifications(job_run, "failure")
      end
    rescue StandardError => e
      job_run.error!(error_class: e.class.name, error_message: e.message)

      enqueue_notifications(job_run, "failure")
    end

    private

    def enqueue_notifications(job_run, event)
      return unless Configuration.get("notifications")

      job_run.job.job_notifications.find_each do |job_notification|
        Notifications::SendJob
          .set(wait: 5.seconds) # Delay sending notifications to avoid race conditions (uncommitted database transaction)
          .perform_later(job_notification.id, job_run.id, event)
      end
    end

    def attach_log(job_run, file)
      return if job_run.output.attached?

      file.rewind

      job_run.output.attach(
        io: file,
        filename: "job_run_#{job_run.sequence}.log",
        content_type: "text/plain",
      )
    end

    def execute_optional_hook(job_run, type)
      return unless Configuration.get("hooks")

      hook = job.send(:"#{type}_hook")

      return unless hook&.enabled?

      result = Hooks::ExecuteService
        .new(hook, job_run:)
        .call

      return if result[:success]
      return if result[:canceled]

      job_run.error!(error_message: "#{type.capitalize}-hook failed (exit #{result[:exit_status]}): #{result[:error]}")
    end
  end
end
