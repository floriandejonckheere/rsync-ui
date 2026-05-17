# frozen_string_literal: true

RSpec.describe Servers::FingerprintService do
  subject(:service) { described_class.new(server) }

  let(:server) { create(:server, fingerprint: nil) }

  describe "#call" do
    before { stub_ssh(fingerprint: NetSSHHelpers::DEFAULT_FINGERPRINT) }

    it "returns the host key fingerprint" do
      result = service.call

      expect(result[:fingerprint]).to eq(NetSSHHelpers::DEFAULT_FINGERPRINT)
    end

    it "returns the host public key" do
      result = service.call

      expect(result[:host_key]).to eq(NetSSHHelpers::DEFAULT_HOST_KEY)
    end

    it "connects regardless of stored fingerprint" do
      expect { service.call }.not_to raise_error
    end
  end
end
