# frozen_string_literal: true

module Jobs
  class ExecuteService < ApplicationService
    STATUS_PATTERN = /^\s*([\d,]+)\s+(\d+)%\s+\S+\s+[\d:]+/

    attr_reader :job,
                :trigger

    def initialize(job, trigger: "manual")
      super()

      @job = job
      @trigger = trigger
    end

    def call
      Rails.logger.info "[#{job.id}] Executing job #{job.name}"

      job_run = job
        .job_runs
        .create!(
          user: job.user,
          trigger:,
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

      command = Rsync::CommandService.new(job:).call

      Tempfile.create(["job_run_#{job_run.sequence}", ".log"]) do |file|
        exit_status = nil

        Rails.logger.info { "[#{job.id}] Executing command: #{command}" }

        Open3.popen2e(command) do |_stdin, output, wait_thr|
          buffer = +""

          loop do
            chunk = output.readpartial(4096)

            Rails.logger.debug { chunk }

            buffer << chunk

            lines = buffer.split(/(?<=[\r\n])/)
            buffer = lines.last&.match?(/[\r\n]\z/) ? +"" : (lines.pop || +"")

            lines.each do |line|
              bytes_copied, progress = parse_status(line)

              if bytes_copied && progress
                job_run.update!(
                  bytes_copied:,
                  progress:,
                )
              else
                file.write(line)
              end
            end
          rescue EOFError
            break
          end

          file.rewind

          job_run.output.attach(
            io: file,
            filename: "job_run_#{job_run.sequence}.log",
            content_type: "text/plain",
          )

          exit_status = wait_thr.value
        end

        Rails.logger.info { "[#{job.id}] Command exited with status: #{exit_status.exitstatus}" }

        job_run.update!(
          status: exit_status.success? ? "completed" : "failed",
          completed_at: Time.zone.now,
        )

        # Post-hook: always runs after rsync (success or failure)
        execute_optional_hook(job_run, "post")

        if exit_status.success?
          execute_optional_hook(job_run, "success")
        else
          execute_optional_hook(job_run, "failure")
        end

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
