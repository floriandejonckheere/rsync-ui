# frozen_string_literal: true

module Processes
  class ExecuteService < ApplicationService
    Result = Data.define(:exit_status)

    attr_reader :command, :job_run

    def initialize(command, job_run)
      super()

      @command = command
      @job_run = job_run
    end

    # Spawns the command in a new process group, records the pid on job_run,
    # yields stdout/stderr (merged) to the block as an IO, and returns the
    # exit status wrapped in a Result.
    #
    # Cancellation is handled externally: JobRuns::CancelJob signals the pid.
    # This service merely waits for the process to exit and reports the
    # status. Callers must check job_run.canceling? after the call to
    # distinguish "exited non-zero because of SIGTERM" from a regular failure.
    def call(&block)
      Open3.popen2e(command, pgroup: true) do |_stdin, output, wait_thr|
        job_run.update!(pid: wait_thr.pid)

        block&.call(output)

        Result.new(exit_status: wait_thr.value)
      end
    ensure
      # Clear the pid once the process has exited so a later cancel job
      # does not signal a recycled PID. Bypass callbacks/validations — this
      # is internal bookkeeping, not a state change.
      job_run.update_column(:pid, nil) if job_run.persisted? # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
