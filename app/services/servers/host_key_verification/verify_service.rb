# frozen_string_literal: true

module Servers
  module HostKeyVerification
    class VerifyService < ApplicationService
      attr_reader :server

      def initialize(server)
        super()

        @server = server
      end

      def verify(options) # rubocop:disable Naming/PredicateMethod
        raise Net::SSH::HostKeyMismatch if server.fingerprint.blank?
        raise Net::SSH::HostKeyMismatch unless server.fingerprint == options[:fingerprint]

        true
      end
    end
  end
end
