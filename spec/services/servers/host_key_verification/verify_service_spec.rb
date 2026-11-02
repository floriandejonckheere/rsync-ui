# frozen_string_literal: true

RSpec.describe Servers::HostKeyVerification::VerifyService do
  subject(:service) { described_class.new(server) }

  let(:server) { build(:server, fingerprint: NetSSHHelpers::DEFAULT_FINGERPRINT) }

  describe "#verify" do
    it "accepts a matching fingerprint" do
      expect(service.verify({ fingerprint: NetSSHHelpers::DEFAULT_FINGERPRINT })).to be true
    end

    it "rejects a mismatching fingerprint" do
      expect { service.verify({ fingerprint: "SHA256:other" }) }.to raise_error Net::SSH::HostKeyMismatch
    end

    context "when the server has no fingerprint" do
      let(:server) { build(:server, fingerprint: nil) }

      it "rejects the host key" do
        expect { service.verify({ fingerprint: NetSSHHelpers::DEFAULT_FINGERPRINT }) }.to raise_error Net::SSH::HostKeyMismatch
      end
    end
  end

  describe "#verify_signature" do
    it "returns the result of the signature check" do
      expect(service.verify_signature { true }).to be true
      expect(service.verify_signature { false }).to be false
    end
  end
end
