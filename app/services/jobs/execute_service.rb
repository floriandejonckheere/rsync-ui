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

      # Generate full command-line
      command = Rsync::CommandService.new(job:).call

      Tempfile.create(["job_run_#{job_run.sequence}", ".log"]) do |file|
        # Execute command
        exit_status = nil

        Rails.logger.info { "[#{job.id}] Executing command: #{command}" }

        Open3.popen2e(command) do |_stdin, output, wait_thr|
          buffer = +""

          loop do
            chunk = output.readpartial(4096)

            Rails.logger.debug { chunk }

            file.write(chunk)
            buffer << chunk

            lines = buffer.split(/(?<=[\r\n])/)
            buffer = lines.last&.match?(/[\r\n]\z/) ? +"" : (lines.pop || +"")

            lines.each do |line|
              bytes_copied, progress = parse_status(line)

              next unless bytes_copied && progress

              job_run.update!(
                bytes_copied:,
                progress:,
              )
            end
          rescue EOFError
            break
          end

          # Attach command output to job run
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
      end
    rescue StandardError => e
      job_run.update!(
        status: "errored",
        completed_at: Time.zone.now,
        error_class: e.class.name,
        error_messages: e.message,
      )
    end

    private

    def parse_status(line)
      match = STATUS_PATTERN.match(line)
      return unless match

      [
        match[1].delete(",").to_i, # Bytes copied
        match[2].to_i, # Progress
      ]
    end
  end
end
