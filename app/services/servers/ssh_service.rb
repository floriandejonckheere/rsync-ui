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
      output = nil

      Net::SSH.start(server.host, server.username, ssh_options) do |ssh|
        output = ssh
          .exec!(command)
          .to_s
      end

      output
    end

    protected

    def command
      raise NotImplementedError
    end

    private

    def ssh_options
      opts = {
        port: server.port,
        timeout: CONNECT_TIMEOUT,
        non_interactive: true,
        verify_host_key: :never,
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
  end
end
