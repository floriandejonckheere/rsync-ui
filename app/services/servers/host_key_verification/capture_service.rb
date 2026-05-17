# frozen_string_literal: true

module Servers
  module HostKeyVerification
    class CaptureService < ApplicationService
      attr_reader :fingerprint,
                  :host_key

      def verify(options) # rubocop:disable Naming/PredicateMethod
        @fingerprint = options[:fingerprint]
        @host_key = "#{options[:key].ssh_type} #{Base64.strict_encode64(options[:key].to_blob)}" if options[:key]

        true
      end
    end
  end
end
