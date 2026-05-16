# frozen_string_literal: true

module Processes
  class ExecuteService < ApplicationService
    CANCEL_MONITOR_INTERVAL = 5

    Result = Data.define(:exit_status, :canceled)

    attr_reader :command, :job_run, :heartbeat_interval

    def initialize(command, job_run, heartbeat_interval: nil)
      super()

      @command = command
      @job_run = job_run
      @heartbeat_interval = heartbeat_interval
    end

    # Runs the command in a new process group, sets job_run.pid, monitors for
    # cancellation requests, and yields the output IO to the block.
    # Returns a Result with the exit status and whether cancellation was requested.
    def call
      Open3.popen2e(command, pgroup: true) do |_stdin, output, wait_thr|
        job_run.update!(pid: wait_thr.pid)

        cancel_sent = false
        mutex = Mutex.new
        condition_variable = ConditionVariable.new
        stop_monitor = false
        last_heartbeat_at = nil

        # Monitor thread: record heartbeats (when configured) and forward cancel
        # requests to the process group. Wakes on a timer or when signaled by
        # the read loop on exit.
        monitor = Thread.new do
          loop do
            mutex.synchronize { condition_variable.wait(mutex, CANCEL_MONITOR_INTERVAL) }

            if heartbeat_interval
              now = Time.zone.now
              if last_heartbeat_at.nil? || (now - last_heartbeat_at) >= heartbeat_interval
                job_run.update!(last_heartbeat_at: now)
                last_heartbeat_at = now
              end
            end

            # Send cancel signal if requested, even when stopping, to handle the
            # case where cancel_requested_at was set during the final read
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

        begin
          yield output
        ensure
          # Wake the monitor so it can exit promptly rather than waiting for its next timer tick
          mutex.synchronize do
            stop_monitor = true
            condition_variable.signal
          end
        end

        monitor.join

        exit_status = wait_thr.value
        canceled = JobRun.where(id: job_run.id).pick(:cancel_requested_at).present?

        Result.new(exit_status:, canceled:)
      end
    end
  end
end
