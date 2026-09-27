# frozen_string_literal: true

module Servers
  class PingService < ApplicationService
    TIMEOUT = 5

    class UnreachableError < StandardError; end

    attr_reader :server

    def initialize(server)
      super()

      @server = server
    end

    # Returns true if a TCP connection can be established to the server's SSH port
    def call
      Socket.tcp(server.host, server.port, connect_timeout: TIMEOUT, resolv_timeout: TIMEOUT, &:close)

      true
    rescue SystemCallError, SocketError, IO::TimeoutError => e
      Rails.logger.info { "[#{server.name}] Server unreachable: #{e.class.name} #{e.message}" }

      false
    end
  end
end
