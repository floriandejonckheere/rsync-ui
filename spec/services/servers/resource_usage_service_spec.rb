# frozen_string_literal: true

RSpec.describe Servers::ResourceUsageService do
  subject(:service) { described_class.new(server) }

  describe "#call" do
    context "when the server runs Linux" do
      let(:server) { create(:server, :linux) }

      it "calls the correct service" do
        linux_service = instance_double(Servers::ResourceUsage::LinuxService, call: true)

        allow(Servers::ResourceUsage::LinuxService)
          .to receive(:new)
          .with(server)
          .and_return linux_service

        service.call

        expect(linux_service)
          .to have_received :call
      end
    end

    context "when the server runs macOS" do
      let(:server) { create(:server, :macos) }

      it "calls the correct service" do
        linux_service = instance_double(Servers::ResourceUsage::MacOSService, call: true)

        allow(Servers::ResourceUsage::MacOSService)
          .to receive(:new)
          .with(server)
          .and_return linux_service

        service.call

        expect(linux_service)
          .to have_received :call
      end
    end

    context "when the server is a Hetzner Storage Box" do
      let(:server) { create(:server, :hetzner) }

      it "calls the correct service" do
        linux_service = instance_double(Servers::ResourceUsage::HetznerService, call: true)

        allow(Servers::ResourceUsage::HetznerService)
          .to receive(:new)
          .with(server)
          .and_return linux_service

        service.call

        expect(linux_service)
          .to have_received :call
      end
    end
  end
end
