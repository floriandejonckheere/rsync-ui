# frozen_string_literal: true

RSpec.describe Servers::SyncSSHConfigJob do
  describe "#perform" do
    it "calls SSHConfigService" do
      allow(Servers::SSHConfigService)
        .to receive(:call)

      described_class.perform_now

      expect(Servers::SSHConfigService)
        .to have_received(:call)
    end
  end
end
