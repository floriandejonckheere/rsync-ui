# frozen_string_literal: true

RSpec.describe Servers::PingService do
  subject(:service) { described_class.new(server) }

  let(:server) { create(:server, :with_password, host: "backup.example.com", port: 2222) }

  describe "#call" do
    context "when the server is reachable" do
      before { allow(Socket).to receive(:tcp) }

      it "returns true" do
        expect(service.call).to be true
      end

      it "connects to the server host and port" do
        service.call

        expect(Socket)
          .to have_received(:tcp)
          .with("backup.example.com", 2222, connect_timeout: described_class::TIMEOUT, resolv_timeout: described_class::TIMEOUT)
      end
    end

    context "when the connection is refused" do
      before { allow(Socket).to receive(:tcp).and_raise(Errno::ECONNREFUSED) }

      it "returns false" do
        expect(service.call).to be false
      end
    end

    context "when the connection times out" do
      before { allow(Socket).to receive(:tcp).and_raise(Errno::ETIMEDOUT) }

      it "returns false" do
        expect(service.call).to be false
      end
    end

    context "when the host cannot be resolved" do
      before { allow(Socket).to receive(:tcp).and_raise(SocketError, "getaddrinfo: Name or service not known") }

      it "returns false" do
        expect(service.call).to be false
      end
    end
  end
end
