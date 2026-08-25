# frozen_string_literal: true

module Servers
  class SSHService < ApplicationService
    CONNECT_TIMEOUT = 10

    attr_reader :server

    def initialize(server)
      super()

      @server = server
    end

    def call
      audit = Audit.create!(server:, command:, category:, started_at: Time.zone.now) if Configuration.get("audits")

      output = +""
      exit_code = nil

      begin
        Net::SSH.start(server.host, server.username, ssh_options) do |ssh|
          ssh.open_channel do |channel|
            channel.exec(command) do |_ch, _success|
              channel.on_data { |_, data| output << data }
              channel.on_extended_data { |_, _, data| output << data }
              channel.on_request("exit-status") { |_, data| exit_code = data.read_long }
            end
          end

          ssh.loop
        end
      rescue StandardError => e
        audit&.update!(output: "#{output}\n#{e.class}: #{e.message}", exit_status: -1, completed_at: Time.zone.now)

        raise
      end

      audit&.update!(output:, exit_status: exit_code, completed_at: Time.zone.now)

      output
    end

    protected

    def command
      raise NotImplementedError
    end

    def category
      raise NotImplementedError
    end

    private

    def ssh_options
      opts = {
        port: server.port,
        timeout: CONNECT_TIMEOUT,
        non_interactive: true,
        verify_host_key:,
      }

      if server.ssh_key.present?
        opts[:key_data] = [server.ssh_key]
        opts[:keys_only] = true
      elsif server.password.present?
        opts[:password] = server.password
        opts[:auth_methods] = ["password"]
      end

      opts
    end

    def verify_host_key
      return :never unless Configuration.get("verify_host_key")

      HostKeyVerification::VerifyService
        .new(server)
    end
  end
end
