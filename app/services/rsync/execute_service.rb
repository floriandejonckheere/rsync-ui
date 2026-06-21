# frozen_string_literal: true

module Rsync
  class ExecuteService < ApplicationService
    attr_reader :job_run

    def initialize(job_run)
      super()

      @job_run = job_run
    end

    # Runs the rsync command and yields each complete output line to the block.
    # Returns an execution result with the exit status.
    #
    # Cancellation is handled externally: JobRuns::CancelJob signals the pid.
    # This service merely waits for the process to exit and reports the
    # status. Callers must check job_run.canceling? after the call to
    # distinguish "exited non-zero because of SIGTERM" from a regular failure.
    def call(&block)
      Timeout.timeout(timeout) do
        Open3.popen2e(job_run.command, pgroup: true) do |_stdin, output, wait_thr|
          job_run.update!(pid: wait_thr.pid)

          buffer = +""

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

          # Flush any remaining buffered output that lacked a trailing newline
          block&.call(buffer) if buffer.present?

          ExecutionResult.new(exit_status: wait_thr.value)
        end
      end
    rescue Timeout::Error
      Rails.logger.debug { "[#{job_run.id}] [#{job_run.name}] Timed out after #{timeout} minutes" }
      debugger
      raise Timeout::Error, "execution expired after #{timeout} minutes"
    ensure
      job_run.update_column(:pid, nil) if job_run.persisted? # rubocop:disable Rails/SkipsModelValidations
    end

    private

    def timeout
      Configuration.get("jobs.timeout").minutes.in_minutes
    end
  end
end
