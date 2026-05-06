# frozen_string_literal: true

RSpec.describe Servers::ResourceUsageService do
  let(:server) { create(:server, :with_password) }

  before { allow(server).to receive(:measure_resource_usage) }

  describe "#call" do
    context "when resource usage has never been probed" do
      it "delegates to server.measure_resource_usage" do
        described_class.call(server)

        expect(server).to have_received(:measure_resource_usage)
      end
    end

    context "when resource usage is stale (older than 5 minutes)" do
      before { create(:resource_usage, server:, probed_at: 10.minutes.ago) }

      it "delegates to server.measure_resource_usage" do
        described_class.call(server)

        expect(server).to have_received(:measure_resource_usage)
      end
    end

    context "when resource usage was probed recently (within 5 minutes)" do
      before { create(:resource_usage, server:, probed_at: 2.minutes.ago) }

      it "skips" do
        described_class.call(server)

        expect(server).not_to have_received(:measure_resource_usage)
      end

      context "with force: true" do
        it "delegates to server.measure_resource_usage regardless" do
          described_class.call(server, force: true)

          expect(server).to have_received(:measure_resource_usage)
        end
      end
    end
  end
end
