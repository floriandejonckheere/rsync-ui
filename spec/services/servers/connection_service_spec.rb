# frozen_string_literal: true

RSpec.describe Servers::ConnectionService do
  subject(:service) { described_class.new(server) }

  let(:server) { build(:server, :with_password) }

  let(:ssh_session) { instance_double(Net::SSH::Connection::Session) }

  before do
    allow(Net::SSH)
      .to receive(:start)
      .and_yield(ssh_session)

    allow(ssh_session)
      .to receive(:exec!)
      .and_return("ok\n")
  end

  describe "#call" do
    it "returns success when SSH connection succeeds" do
      expect(service.call).to eq success: true
    end

    it "runs 'echo ok' over SSH" do
      service.call

      expect(ssh_session)
        .to have_received(:exec!)
        .with "echo ok"
    end

    it "passes the correct SSH options" do
      service.call

      expect(Net::SSH)
        .to have_received(:start)
        .with(server.host, server.username, hash_including(port: server.port, password: server.password, auth_methods: ["password"]))
    end

    context "when ssh_key is provided instead of password" do
      let(:server) { build(:server, :with_ssh_key) }

      it "passes the correct SSH options" do
        service.call

        expect(Net::SSH)
          .to have_received(:start)
          .with(server.host, server.username, hash_including(port: server.port, key_data: [server.ssh_key], keys_only: true))
      end
    end

    context "when SSH authentication fails" do
      before do
        allow(Net::SSH)
          .to receive(:start)
          .and_raise(Net::SSH::AuthenticationFailed, "Authentication failed for admin@example.com")
      end

      it "returns the failure message" do
        expect(service.call).to eq success: false, message: "Net::SSH::AuthenticationFailed: Authentication failed for admin@example.com"
      end
    end

    context "when connection times out" do
      before do
        allow(Net::SSH)
          .to receive(:start)
          .and_raise(Net::SSH::ConnectionTimeout, "timed out")
      end

      it "returns the failure message" do
        expect(service.call).to eq success: false, message: "Net::SSH::ConnectionTimeout: timed out"
      end
    end

    context "when host is unreachable" do
      before do
        allow(Net::SSH)
          .to receive(:start)
          .and_raise(Errno::ECONNREFUSED, "Connection refused - connect(2) for example.com port 22")
      end

      it "returns the failure message" do
        expect(service.call).to eq success: false, message: "Errno::ECONNREFUSED: Connection refused - Connection refused - connect(2) for example.com port 22"
      end
    end
  end
end
