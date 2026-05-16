# frozen_string_literal: true

module Rsync
  class ExecuteService < ApplicationService
    Result = Processes::ExecuteService::Result

    attr_reader :command, :job_run

    def initialize(command, job_run)
      super()

      @command = command
      @job_run = job_run
    end

    # Runs the rsync command and yields each complete output line to the block.
    # Returns a Result with the exit status and whether cancellation was requested.
    def call(&block)
      Processes::ExecuteService.new(command, job_run, heartbeat_interval:).call do |output|
        # Readpartial chunk buffer
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
      end
    end

    private

    def heartbeat_interval
      @heartbeat_interval ||= Configuration.get("jobs.heartbeat_interval").to_i
    end
  end
end
