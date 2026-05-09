# frozen_string_literal: true

module Jobs
  class ExecuteService < ApplicationService
    STATUS_PATTERN = /^\s*([\d,]+)\s+(\d+)%\s+\S+\s+[\d:]+/

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

      job_run.update!(
        status: "running",
        started_at: Time.zone.now,
      )

      enqueue_notifications(job_run, "start")

      # Pre-hook: halt execution if it fails
      if Configuration.get("hooks")
        hook = job.pre_hook

        if hook&.enabled?
          result = Hooks::ExecuteService.new(hook, job_run:).call

          unless result[:success]
            job_run.update!(
              status: "errored",
              completed_at: Time.zone.now,
              error_messages: "Pre-hook failed (exit #{result[:exit_status]}): #{result[:error]}",
            )
            enqueue_notifications(job_run, "failure")

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
          bytes_copied, progress = parse_status(line) if job.opt_progress || job.opt_progress2

          # Broadcast status line
          ActionCable.server.broadcast("job_run_logs_#{job_run.id}", { type: bytes_copied && progress ? "status" : "log", content: line }) if Configuration.get("streaming")

          if job.opt_progress2 && bytes_copied && progress
            job_run.update!(
              bytes_copied:,
              progress:,
            )

            # Broadcast progress
            ActionCable.server.broadcast("job_run_logs_#{job_run.id}", { type: "progress", status_text: I18n.t("job_runs.status.running_progress", progress:) }) if Configuration.get("streaming")

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
        if result.canceled
          job_run.cancel!
          broadcast_complete(job_run) if Configuration.get("streaming")
          next
        end

        # Mark job as completed or failed based on the exit status
        job_run.update!(
          status: exit_status.success? ? "completed" : "failed",
          completed_at: Time.zone.now,
        )

        broadcast_complete(job_run) if Configuration.get("streaming")

        # Post-hook: always runs after rsync (success or failure)
        execute_optional_hook(job_run, "post")

        # Success/failure hooks: only run if rsync succeeded or failed
        execute_optional_hook(job_run, exit_status.success? ? "success" : "failure")

        # Send notifications
        enqueue_notifications(job_run, exit_status.success? ? "success" : "failure")
      end
    rescue StandardError => e
      job_run.update!(
        status: "errored",
        completed_at: Time.zone.now,
        error_class: e.class.name,
        error_messages: e.message,
      )

      enqueue_notifications(job_run, "failure")
    end

    private

    def parse_status(line)
      match = STATUS_PATTERN.match(line)
      return unless match

      [
        match[1].delete(",").to_i,
        match[2].to_i,
      ]
    end

    def enqueue_notifications(job_run, event)
      return unless Configuration.get("notifications")

      job_run.job.job_notifications.find_each do |job_notification|
        Notifications::SendJob
          .set(wait: 5.seconds) # Delay sending notifications to avoid race conditions (uncommitted database transaction)
          .perform_later(job_notification.id, job_run.id, event)
      end
    end

    def broadcast_complete(job_run)
      status = job_run.status
      status_text = I18n.t("job_runs.status.#{status}")

      ActionCable.server.broadcast(
        "job_run_logs_#{job_run.id}",
        {
          type: "complete",
          status:,
          status_text:,
          completed_at_text: job_run.completed_at ? I18n.l(job_run.completed_at, format: :short) : "—",
        },
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

      job_run.update!(
        status: "errored",
        error_messages: "#{type.capitalize}-hook failed (exit #{result[:exit_status]}): #{result[:error]}",
      )
    end
  end
end
