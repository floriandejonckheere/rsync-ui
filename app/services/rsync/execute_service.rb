# frozen_string_literal: true

module Rsync
  class ExecuteService < ApplicationService
    Result = Data.define(:exit_status)

    attr_reader :command, :job_run

    def initialize(command, job_run)
      super()

      @command = command
      @job_run = job_run
    end

    # Runs the rsync command and yields each complete output line to the block.
    # Returns a Result with the exit status.
    #
    # Cancellation is handled externally: JobRuns::CancelJob signals the pid.
    # This service merely waits for the process to exit and reports the
    # status. Callers must check job_run.canceling? after the call to
    # distinguish "exited non-zero because of SIGTERM" from a regular failure.
    def call(&block)
      Open3.popen2e(command, pgroup: true) do |_stdin, output, wait_thr|
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

        Result.new(exit_status: wait_thr.value)
      end
    ensure
      job_run.update_column(:pid, nil) if job_run.persisted? # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
