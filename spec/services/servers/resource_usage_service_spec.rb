# frozen_string_literal: true

RSpec.describe Servers::ResourceUsageService do
  let(:server) { create(:server, :with_password, path: "/") }
  let(:fixture) { Rails.root.join("spec/support/fixtures/probe_output.txt").read }
  let(:ssh_session) { instance_double(Net::SSH::Connection::Session) }

  before do
    allow(Net::SSH)
      .to receive(:start)
      .and_yield(ssh_session)

    allow(ssh_session)
      .to receive(:exec!)
      .and_return(fixture)
  end

  describe "#call" do
    it "updates the server resource_usage with parsed metrics" do
      described_class.call(server)

      usage = server.reload.resource_usage

      expect(usage.status).to eq "ok"
      expect(usage.error_class).to be_nil
      expect(usage.error_message).to be_nil
      expect(usage.probed_at).to be_within(5.seconds).of Time.zone.now
      expect(usage.cpu_count).to eq 4
      expect(usage.cpu_usage).to be_within(0.01).of 30.0
      expect(usage.memory_total).to eq(8_000_000 * 1024)
      expect(usage.memory_used).to eq((8_000_000 - 2_000_000) * 1024)
      expect(usage.disk_total).to eq 107_374_182_400
      expect(usage.disk_used).to eq 53_687_091_200
      expect(usage.uptime_seconds).to eq 123_456
      expect(usage.load_avg_1).to eq 0.42
      expect(usage.load_avg_5).to eq 0.55
      expect(usage.load_avg_15).to eq 0.60
    end

    it "quotes the server path into the remote command" do
      server.update!(path: "/var/data space")

      described_class.call(server)

      expect(ssh_session).to have_received(:exec!)
        .with(a_string_including("/var/data\\ space"))
    end

    context "when SSH connection fails" do
      before do
        allow(Net::SSH)
          .to receive(:start)
          .and_raise(Net::SSH::ConnectionTimeout, "timed out")
      end

      it "records status=failed and error message" do
        described_class.call(server)

        usage = server.reload.resource_usage

        expect(usage.status).to eq "failed"
        expect(usage.error_class).to eq "Net::SSH::ConnectionTimeout"
        expect(usage.error_message).to include "timed out"
        expect(usage.cpu_usage).to be_nil
      end
    end

    context "when stdout is malformed" do
      before { allow(ssh_session).to receive(:exec!).and_return("garbage") }

      it "records status=failed" do
        described_class.call(server)

        expect(server.reload.resource_usage.status).to eq("failed")
      end
    end

    context "when resource usage was probed recently (within 5 minutes)" do
      before { create(:resource_usage, server:, probed_at: 2.minutes.ago) }

      it "skips the SSH call" do
        described_class.call(server)

        expect(Net::SSH).not_to have_received(:start)
      end

      context "when force: true" do
        it "performs the SSH call regardless" do
          described_class.call(server, force: true)

          expect(Net::SSH).to have_received(:start)
        end

        it "updates resource_usage" do
          described_class.call(server, force: true)

          expect(server.reload.resource_usage.probed_at).to be_within(5.seconds).of(Time.zone.now)
        end
      end
    end

    context "when resource usage is stale (older than 5 minutes)" do
      before { create(:resource_usage, server:, probed_at: 10.minutes.ago) }

      it "performs the SSH call" do
        described_class.call(server)

        expect(Net::SSH).to have_received(:start)
      end
    end

    context "when resource usage has never been probed" do
      it "performs the SSH call" do
        described_class.call(server)

        expect(Net::SSH).to have_received(:start)
      end
    end

    context "when server has an SSH key" do
      let(:server) { create(:server, :with_ssh_key, path: "/") }

      it "passes key_data to Net::SSH.start" do
        described_class.call(server)

        expect(Net::SSH).to have_received(:start).with(
          server.host,
          server.username,
          hash_including(port: server.port, key_data: [server.ssh_key], non_interactive: true),
        )
      end
    end
  end
end
