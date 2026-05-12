# frozen_string_literal: true

module Rsync
  class ExecuteService < ApplicationService
    CANCEL_MONITOR_INTERVAL = 5

    Result = Data.define(:exit_status, :canceled)

    attr_reader :command, :job_run

    def initialize(command, job_run)
      super()

      @command = command
      @job_run = job_run
    end

    # Runs the rsync command and yields each complete output line to the block.
    # Returns a Result with the exit status and whether cancellation was requested.
    def call(&block)
      exit_status = nil
      canceled = false

      # Run rsync in a new process group so SIGTERM reaches all child processes
      Open3.popen2e(command, pgroup: true) do |_stdin, output, wait_thr|
        job_run.update!(pid: wait_thr.pid)

        # Readpartial chunk buffer
        buffer = +""

        # Prevents sending SIGTERM more than once
        cancel_sent = false

        # Protect concurrent access in monitor thread
        mutex = Mutex.new

        # Signal monitor thread to continue
        condition_variable = ConditionVariable.new

        # Signal monitor thread to exit
        stop_monitor = false

        # Monitor thread last seen at
        last_heartbeat_at = nil

        # Monitor thread: record heartbeats and forward cancel requests to the process group
        # Wake on a timer or when signaled by the read loop on exit
        monitor = Thread.new do
          loop do
            mutex.synchronize { condition_variable.wait(mutex, CANCEL_MONITOR_INTERVAL) }

            now = Time.zone.now
            if last_heartbeat_at.nil? || (now - last_heartbeat_at) >= heartbeat_interval
              job_run.update!(last_heartbeat_at: now)

              last_heartbeat_at = now
            end

            # Send cancel signal if requested, even when stopping, to handle the
            # case where cancel_requested_at was set during the final readpartial
            if !cancel_sent && JobRun.where(id: job_run.id).pick(:cancel_requested_at).present?
              begin
                Process.kill("TERM", -wait_thr.pid)
              rescue Errno::ESRCH
                nil
              end

              cancel_sent = true
            end

            # Exit when requested by the read loop on exit
            break if stop_monitor
          end
        end

        # Read output and yield complete lines to the block
        begin
          loop do
            chunk = output.readpartial(4096)

            Rails.logger.debug { chunk }

            buffer << chunk

            # Split on line endings, keeping the terminator attached; hold back any trailing incomplete line
            lines = buffer.split(/(?<=[\r\n])/)
            buffer = lines.last&.match?(/[\r\n]\z/) ? +"" : (lines.pop || +"")

            lines.each { |line| block&.call(line) }
          rescue EOFError
            break
          end
        ensure
          # Wake the monitor so it can exit promptly rather than waiting for its next timer tick
          mutex.synchronize do
            stop_monitor = true
            condition_variable.signal
          end
        end

        monitor.join

        # Flush any remaining buffered output that lacked a trailing newline
        block&.call(buffer) if buffer.present?

        exit_status = wait_thr.value
        canceled = job_run.reload.cancel_requested_at?
      end

      Result.new(exit_status:, canceled:)
    end

    private

    def heartbeat_interval
      @heartbeat_interval ||= Configuration.get("jobs.heartbeat_interval").to_i
    end
  end
end
