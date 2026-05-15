# frozen_string_literal: true

RSpec.describe Servers::ResourceUsage::MacOSService do
  let(:service) { described_class.new(server) }

  let(:server) { create(:server, :with_password, path: "/") }
  let(:fixture) { Rails.root.join("spec/support/fixtures/probe_output_macos.txt").read }

  before { stub_ssh(output: fixture) }

  describe "#call" do
    it "parses all metrics from output" do
      service.call

      usage = server.reload.resource_usage

      expect(usage.status).to eq "ok"
      expect(usage.error_class).to be_nil
      expect(usage.error_message).to be_nil
      expect(usage.probed_at).to be_within(5.seconds).of Time.zone.now
      expect(usage.cpu_count).to eq 10
      expect(usage.cpu_usage).to be_within(0.01).of 13.33
      expect(usage.memory_total).to eq(33_554_432 * 1024)
      expect(usage.memory_used).to eq(22_878_704 * 1024)
      expect(usage.disk_total).to eq 1_995_218_165_760
      expect(usage.disk_used).to eq 336_623_890_432
      expect(usage.uptime_seconds).to eq 2_928_276
      expect(usage.load_avg_1).to eq 3.81
      expect(usage.load_avg_5).to eq 3.97
      expect(usage.load_avg_15).to eq 4.59
    end

    it "embeds the server path directly in the command" do
      server.update!(path: "/var/data space")

      channel = stub_ssh(output: fixture)
      service.call

      expect(channel)
        .to have_received(:exec)
        .with a_string_including("/var/data\\ space")
    end

    context "when SSH connection fails" do
      before do
        allow(Net::SSH)
          .to receive(:start)
          .and_raise Net::SSH::ConnectionTimeout, "timed out"
      end

      it "records status=failed with error details" do
        service.call

        usage = server.reload.resource_usage

        expect(usage.status).to eq "failed"
        expect(usage.error_class).to eq "Net::SSH::ConnectionTimeout"
        expect(usage.error_message).to include "timed out"
        expect(usage.cpu_usage).to be_nil
      end
    end

    context "when stdout is malformed" do
      before { stub_ssh(output: "garbage") }

      it "records status=failed" do
        service.call

        expect(server.reload.resource_usage.status).to eq "failed"
      end
    end
  end
end
