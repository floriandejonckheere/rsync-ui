# frozen_string_literal: true

module Servers
  class FingerprintService < SSHService
    def call
      super

      { success: true, fingerprint: @capturing_verifier&.fingerprint }
    rescue StandardError => e
      { success: false, message: "#{e.class}: #{e.message}" }
    end

    protected

    def command
      "true"
    end

    private

    def verify_host_key
      @capturing_verifier = HostKeyVerification::CaptureService.new
    end
  end
end
