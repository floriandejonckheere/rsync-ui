# frozen_string_literal: true

module Servers
  module HostKeyVerification
    class CaptureService < ApplicationService
      attr_reader :fingerprint

      def verify(options) # rubocop:disable Naming/PredicateMethod
        @fingerprint = options[:fingerprint]

        true
      end
    end
  end
end
