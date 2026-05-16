# frozen_string_literal: true

module Servers
  class ResourceUsageService < ApplicationService
    attr_reader :server

    def initialize(server)
      super()

      @server = server
    end

    def call
      case server.operating_system
      when "linux"
        Servers::ResourceUsage::LinuxService
          .new(server)
          .call
      when "macos"
        Servers::ResourceUsage::MacOSService
          .new(server)
          .call
      when "hetzner"
        Servers::ResourceUsage::HetznerService
          .new(server)
          .call
      else
        raise "Unsupported operating system: #{operating_system}"
      end
    end
  end
end
