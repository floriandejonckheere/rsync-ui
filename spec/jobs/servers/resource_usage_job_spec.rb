# frozen_string_literal: true

RSpec.describe Servers::ResourceUsageJob do
  subject(:job) { described_class.new }

  let(:service) { instance_double(Servers::ResourceUsageService, call: true) }
  let(:server) { create(:server, :with_resource_usage) }

  describe "#perform" do
    it "calls Servers::ResourceUsageService" do
      allow(Servers::ResourceUsageService)
        .to receive(:new)
        .with(server)
        .and_return service

      job.perform(server)

      expect(service)
        .to have_received(:call)
    end

    context "when the server's resource usage was measured recently" do
      with_configuration "resource_usage.interval" => 5

      let(:server) { build(:server, resource_usage: create(:resource_usage, probed_at: 2.minutes.ago)) }

      it "does not call Servers::ResourceUsageService" do
        allow(Servers::ResourceUsageService)
          .to receive(:new)
          .with(server)
          .and_return service

        job.perform(server)

        expect(service)
          .not_to have_received(:call)
      end

      context "when force is true" do
        it "calls Servers::ResourceUsageService" do
          allow(Servers::ResourceUsageService)
            .to receive(:new)
            .with(server)
            .and_return service

          job.perform(server, force: true)

          expect(service)
            .to have_received(:call)
        end
      end
    end
  end
end
