# frozen_string_literal: true

module Jobs
  class ExecuteService < ApplicationService
    STATUS_PATTERN = /^\s*([\d,]+)\s+(\d+)%\s+\S+\s+[\d:]+/
    CANCEL_MONITOR_INTERVAL = 5

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
        exit_status = nil
        canceled = false

        Rails.logger.info { "[#{job.id}] Executing command: #{command}" }

        # Write full command to the log file
        file.write("#{command}\n")

        # Start command and read output line-by-line
        Open3.popen2e(command, pgroup: true) do |_stdin, output, wait_thr|
          job_run.update!(pid: wait_thr.pid)

          buffer = +""

          # User has requested job cancellation
          cancel_sent = false

          mutex = Mutex.new
          condition_variable = ConditionVariable.new

          # Signal the companion thread to stop
          stop_monitor = false

          # Companion thread monitors cancellation requests and kills process when rsync produces no output
          monitor = Thread.new do
            loop do
              mutex.synchronize { condition_variable.wait(mutex, CANCEL_MONITOR_INTERVAL) }

              break if stop_monitor

              next if cancel_sent

              next if JobRun.where(id: job_run.id).pick(:cancel_requested_at).blank?

              begin
                Process.kill("TERM", -wait_thr.pid)
              rescue Errno::ESRCH
                nil
              end

              cancel_sent = true
            end
          end

          loop do
            chunk = output.readpartial(4096)

            Rails.logger.debug { chunk }

            buffer << chunk

            lines = buffer.split(/(?<=[\r\n])/)
            buffer = lines.last&.match?(/[\r\n]\z/) ? +"" : (lines.pop || +"")

            lines.each do |line|
              bytes_copied, progress = parse_status(line) if job.opt_progress || opt_progress2

              # Save progress only if --info=progress2 is enabled, not when only --progress is specified
              if job.opt_progress2 && bytes_copied && progress
                job_run.update!(
                  bytes_copied:,
                  progress:,
                )
              else
                file.write(line)
              end
            end

            if !cancel_sent && JobRun.where(id: job_run.id).pick(:cancel_requested_at).present?
              begin
                Process.kill("TERM", -wait_thr.pid)
              rescue Errno::ESRCH
                nil
              end
              cancel_sent = true
            end
          rescue EOFError
            break
          ensure
            mutex.synchronize do
              stop_monitor = true
              condition_variable.signal
            end
          end

          monitor.join

          file.write(buffer) if buffer.present?

          file.rewind

          job_run.output.attach(
            io: file,
            filename: "job_run_#{job_run.sequence}.log",
            content_type: "text/plain",
          )

          exit_status = wait_thr.value

          canceled = job_run.reload.cancel_requested_at?
        end

        Rails.logger.info { "[#{job.id}] Command exited with status: #{exit_status.exitstatus || "signal #{exit_status.termsig}"}" }

        # Mark job as canceled if cancellation was requested
        next job_run.cancel! if canceled

        # Mark job as completed or failed based on the exit status
        job_run.update!(
          status: exit_status.success? ? "completed" : "failed",
          completed_at: Time.zone.now,
        )

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
