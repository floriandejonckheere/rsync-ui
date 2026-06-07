# frozen_string_literal: true

RSpec.describe Servers::ConnectionService do
  subject(:service) { described_class.new(server) }

  with_configuration "audits" => false

  let(:server) { create(:server, :with_password) }

  before { stub_ssh(output: "ok\n") }

  describe "#call" do
    it "returns success when SSH connection succeeds" do
      expect(service.call).to eq success: true
    end

    it "runs 'echo ok' over SSH" do
      channel = stub_ssh(output: "ok\n")

      service.call

      expect(channel).to have_received(:exec).with "echo ok"
    end

    it "passes the correct SSH options" do
      service.call

      expect(Net::SSH)
        .to have_received(:start)
        .with(server.host, server.username, hash_including(port: server.port, password: server.password, auth_methods: ["password"]))
    end

    it "updates probed_at and last_seen_at on success" do
      service.call

      server.reload

      expect(server.probed_at).to be_within(5.seconds).of(Time.zone.now)
      expect(server.last_seen_at).to be_within(5.seconds).of(Time.zone.now)
      expect(server.error_class).to be_nil
      expect(server.error_message).to be_nil
    end

    context "when ssh_key is provided instead of password" do
      let(:server) { create(:server, :with_ssh_key) }

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

      it "updates probed_at and error fields, leaves last_seen_at unchanged" do
        service.call

        server.reload

        expect(server.probed_at).to be_within(5.seconds).of(Time.zone.now)
        expect(server.last_seen_at).to be_nil
        expect(server.error_class).to eq("Net::SSH::AuthenticationFailed")
        expect(server.error_message).to include("Authentication failed")
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
