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

      Open3.popen2e(command, pgroup: true) do |_stdin, output, wait_thr|
        job_run.update!(pid: wait_thr.pid)

        buffer = +""
        cancel_sent = false
        mutex = Mutex.new
        condition_variable = ConditionVariable.new
        stop_monitor = false

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

          lines.each { |line| block&.call(line) }

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

        block&.call(buffer) if buffer.present?

        exit_status = wait_thr.value
        canceled = job_run.reload.cancel_requested_at?
      end

      Result.new(exit_status:, canceled:)
    end
  end
end
