# frozen_string_literal: true

RSpec.describe Servers::DeployService do
  subject(:service) { described_class.new(server) }

  let(:server) { create(:server, :with_password) }

  with_configuration "connectivity.ssh_key.algorithm" => "rsa",
                     "connectivity.ssh_key.length" => 2048

  before { stub_ssh }

  describe "#call" do
    it "generates a new SSH key" do
      expect { service.call }
        .to change { server.reload.ssh_key }
        .from(nil)
    end

    it "clears the password and stores the private key" do
      expect { service.call }
        .to change(server, :password).to(nil)
        .and change(server, :ssh_key).from(nil)
    end

    it "returns success" do
      expect(service.call).to eq success: true

      server.reload
      expect(server.error_class).to be_nil
      expect(server.error_message).to be_nil
      expect(server.probed_at).not_to be_nil
      expect(server.last_seen_at).not_to be_nil
    end

    context "when the SSH key is RSA" do
      with_configuration "connectivity.ssh_key.algorithm" => "rsa",
                         "connectivity.ssh_key.length" => 2048

      it "deploys the public key" do
        channel = stub_ssh

        service.call

        expect(channel)
          .to have_received(:exec)
          .with(match(%r(echo "ssh-rsa .+ Rsync UI key" >> ~/.ssh/authorized_keys)))
      end
    end

    context "when the SSH key is ECDSA" do
      with_configuration "connectivity.ssh_key.algorithm" => "ecdsa"

      it "deploys the public key" do
        channel = stub_ssh

        service.call

        expect(channel)
          .to have_received(:exec)
          .with(match(%r(echo "ecdsa-sha2-nistp256 .+ Rsync UI key" >> ~/.ssh/authorized_keys)))
      end
    end

    context "when the SSH key is ED25519" do
      with_configuration "connectivity.ssh_key.algorithm" => "ed25519"

      it "deploys the public key" do
        channel = stub_ssh

        service.call

        expect(channel)
          .to have_received(:exec)
          .with(match(%r(echo "ssh-ed25519 .+ Rsync UI key" >> ~/.ssh/authorized_keys)))
      end
    end

    context "when the server already has an SSH key" do
      let(:server) { create(:server, :with_ssh_key) }

      it "does not generate a new key pair" do
        expect { service.call }
          .not_to change(server, :ssh_key)
      end

      it "returns failure" do
        expect(service.call).to eq success: false,
                                   message: "Server already has an SSH key"

        server.reload
        expect(server.error_class).not_to be_nil
        expect(server.error_message).not_to be_nil
        expect(server.probed_at).not_to be_nil
        expect(server.last_seen_at).not_to be_nil
      end
    end

    context "when SSH authentication fails" do
      before do
        allow(Net::SSH)
          .to receive(:start)
          .and_raise(Net::SSH::AuthenticationFailed, "Authentication failed for user@host")
      end

      it "returns failure" do
        expect(service.call).to eq success: false,
                                   message: "Net::SSH::AuthenticationFailed: Authentication failed for user@host"

        server.reload

        expect(server.probed_at).not_to be_nil
        expect(server.error_class).to eq "Net::SSH::AuthenticationFailed"
        expect(server.error_message).to eq "Authentication failed for user@host"
      end
    end

    context "when the connection times out" do
      before do
        allow(Net::SSH)
          .to receive(:start)
          .and_raise(Net::SSH::ConnectionTimeout, "timed out")
      end

      it "returns failure" do
        expect(service.call).to eq success: false,
                                   message: "Net::SSH::ConnectionTimeout: timed out"

        server.reload
        expect(server.probed_at).not_to be_nil
        expect(server.error_class).to eq "Net::SSH::ConnectionTimeout"
        expect(server.error_message).to eq "timed out"
      end
    end
  end
end
