# frozen_string_literal: true

RSpec.describe Servers::DeployService do
  subject(:service) { described_class.new(server) }

  let(:server) { create(:server, :with_password) }
  let(:ssh_session) { instance_double(Net::SSH::Connection::Session) }
  let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }

  before do
    allow(Net::SSH)
      .to receive(:start)
      .and_yield(ssh_session)

    allow(ssh_session)
      .to receive(:exec!)
      .and_return("")

    allow(Servers::SSHKeyService)
      .to receive(:call)
      .and_return({ private_key: rsa_key, public_key: rsa_key.public_key })
  end

  describe "#call" do
    it "generates a new SSH key pair" do
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
      it "deploys the public key" do
        service.call

        expect(ssh_session)
          .to have_received(:exec!)
          .with(match(%r(echo "ssh-rsa .+ Rsync UI key" >> ~/.ssh/authorized_keys)))
      end
    end

    context "when the SSH key is ECDSA" do
      let(:ecdsa_key) { OpenSSL::PKey::EC.generate("prime256v1") }

      before do
        allow(Servers::SSHKeyService)
          .to receive(:call)
          .and_return({ private_key: ecdsa_key, public_key: ecdsa_key })
      end

      it "deploys the public key" do
        service.call

        expect(ssh_session)
          .to have_received(:exec!)
          .with(match(%r(echo "ecdsa-sha2-nistp256 .+ Rsync UI key" >> ~/.ssh/authorized_keys)))
      end
    end

    context "when the SSH key is ED25519" do
      let(:ed25519_key) { OpenSSL::PKey.generate_key("ED25519") }

      before do
        allow(Servers::SSHKeyService)
          .to receive(:call)
          .and_return({ private_key: ed25519_key, public_key: ed25519_key })
      end

      it "deploys the public key" do
        service.call

        expect(ssh_session)
          .to have_received(:exec!)
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
