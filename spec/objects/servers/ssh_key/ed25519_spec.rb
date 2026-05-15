# frozen_string_literal: true

RSpec.describe Servers::SSHKey::ED25519 do
  subject(:ssh_key) { described_class.new }

  it { is_expected.to be_a Servers::SSHKey }

  describe "#private_key" do
    it "returns the private key in PEM format" do
      expect(ssh_key.private_key).to include "-----BEGIN PRIVATE KEY-----"
      expect(ssh_key.private_key).to include "-----END PRIVATE KEY-----"
    end
  end

  describe "#public_key" do
    it "returns the public key in PEM format" do
      expect(ssh_key.public_key).to include "-----BEGIN PUBLIC KEY-----"
      expect(ssh_key.public_key).to include "-----END PUBLIC KEY-----"
    end
  end

  describe "#ssh_type" do
    it { expect(ssh_key.ssh_type).to eq "ssh-ed25519" }
  end

  describe "#openssh_public_key" do
    it "returns the public key in OpenSSH format" do
      expect(ssh_key.openssh_public_key).to start_with "AAAA"
    end
  end
end
