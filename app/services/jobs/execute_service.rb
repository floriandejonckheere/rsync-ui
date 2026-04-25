# frozen_string_literal: true

module Jobs
  class ExecuteService < ApplicationService
    attr_reader :job, :trigger

    def initialize(job, trigger: "manual")
      super()

      @job = job
      @trigger = trigger
    end

    def call
      job_run = job.job_runs.create!(user: job.user, trigger:, status: "pending")
      tmpfile = nil

      begin
        job_run.update!(status: "running", started_at: Time.current)

        # Generate full command-line
        command = Rsync::CommandService.new(job:).call

        tmpfile = Tempfile.new(["job_run_#{job_run.sequence}", ".log"])

        # Execute command
        exit_status = nil
        Open3.popen2e(command) do |_stdin, output, wait_thr|
          IO.copy_stream(output, tmpfile)

          exit_status = wait_thr.value
        end

        # Attach command output to job run
        tmpfile.rewind
        job_run.output.attach(
          io: tmpfile,
          filename: "job_run_#{job_run.sequence}.log",
          content_type: "text/plain",
        )

        job_run.update!(
          status: exit_status.success? ? "completed" : "failed",
          completed_at: Time.zone.now,
        )
      rescue StandardError => e
        job_run.update!(
          status: "errored",
          completed_at: Time.zone.now,
          error_class: e.class.name,
          error_messages: e.message,
        )
      ensure
        tmpfile&.close
        tmpfile&.unlink
      end
    end
  end
end
