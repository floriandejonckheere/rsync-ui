# frozen_string_literal: true

RSpec.describe Servers::ResourceUsage::HetznerService do
  let(:service) { described_class.new(server) }

  let(:server) { create(:server, :with_password, path: "/") }
  let(:fixture) { Rails.root.join("spec/support/fixtures/probe_output_hetzner.txt").read }

  before { stub_ssh(output: fixture) }

  describe "#call" do
    it "parses disk metrics only" do
      service.call

      usage = server.reload.resource_usage

      expect(usage.status).to eq "ok"
      expect(usage.error_class).to be_nil
      expect(usage.error_message).to be_nil
      expect(usage.probed_at).to be_within(5.seconds).of Time.zone.now
      expect(usage.disk_total).to eq(1_056_293_120 * 1024)
      expect(usage.disk_used).to eq(484_460_288 * 1024)
      expect(usage.cpu_count).to be_nil
      expect(usage.cpu_usage).to be_nil
      expect(usage.memory_total).to be_nil
      expect(usage.memory_used).to be_nil
      expect(usage.uptime_seconds).to be_nil
      expect(usage.load_avg_1).to be_nil
    end

    it "runs the bare df command" do
      channel = stub_ssh(output: fixture)

      service.call

      expect(channel).to have_received(:exec).with "df"
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
