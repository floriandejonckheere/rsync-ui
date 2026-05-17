# frozen_string_literal: true

RSpec.describe Servers::HostKeyVerification::CaptureService do
  subject(:service) { described_class.new }

  let(:key) { double("host_key", ssh_type: "ssh-ed25519", to_blob: NetSSHHelpers::DEFAULT_HOST_KEY_BLOB) } # rubocop:disable RSpec/VerifiedDoubles

  describe "#verify" do
    it "captures the fingerprint and host key" do
      expect(service.verify({ fingerprint: NetSSHHelpers::DEFAULT_FINGERPRINT, key: })).to be true

      expect(service.fingerprint).to eq NetSSHHelpers::DEFAULT_FINGERPRINT
      expect(service.host_key).to eq NetSSHHelpers::DEFAULT_HOST_KEY
    end
  end
end
