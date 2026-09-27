# frozen_string_literal: true

require "shellwords"

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
    def call(&)
      # Private key and password are only written for the duration of the command
      with_credentials { |env| execute(env, &) }
    rescue Timeout::Error
      Rails.logger.debug { "[#{job_run.id}] [#{job_run.name}] Timed out after #{timeout.inspect}" }

      raise Timeout::Error, "execution expired after #{timeout.inspect}"
    ensure
      job_run.update_column(:pid, nil) if job_run.persisted? # rubocop:disable Rails/SkipsModelValidations
    end

    private

    def execute(env, &block)
      Timeout.timeout(timeout.in_seconds) do
        Open3.popen2e(env, *Shellwords.split(job_run.command), pgroup: true) do |_stdin, output, wait_thr|
          job_run.update!(pid: wait_thr.pid)

          # Binary string buffer
          buffer = +"".b

          loop do
            chunk = output.readpartial(4096)

            Rails.logger.debug { chunk }

            buffer << chunk

            # Split on line endings, keeping the terminator attached; hold back any trailing incomplete line
            lines = buffer.split(/(?<=[\r\n])/)
            buffer = lines.last&.match?(/[\r\n]\z/) ? +"".b : (lines.pop || +"".b)

            # Encode as UTF-8
            lines.each { |line| block&.call(line.force_encoding(Encoding::UTF_8).scrub) }
          rescue EOFError
            break
          end

          # Flush any remaining buffered output that lacked a trailing newline
          block&.call(buffer.force_encoding(Encoding::UTF_8).scrub) if buffer.present?

          ExecutionResult.new(success: wait_thr.value.success?, exit_status: wait_thr.value.exitstatus)
        end
      end
    end

    # Yields the environment variables required to authenticate against the remote server (if any)
    def with_credentials
      server = job_run.job.remote_server

      if server&.ssh_key.present?
        # Write private key to a private temporary directory, removed afterwards
        Dir.mktmpdir("rsync_ui_ssh") do |dir|
          key_path = File.join(dir, "id")
          File.write(key_path, server.ssh_key, perm: 0o600)

          yield({ Servers::SSHConfigService::IDENTITY_FILE_ENV => key_path })
        end
      elsif server&.password.present?
        # Pass password to sshpass through the environment
        yield({ "SSHPASS" => server.password })
      else
        yield({})
      end
    end

    def timeout
      Configuration.get("jobs.timeout").minutes
    end
  end
end
