# frozen_string_literal: true

RSpec.describe Repositories::DiskSizeJob do
  subject(:job) { described_class.new }

  let(:service) { instance_double(Repositories::DiskSizeService, call: true) }
  let(:repository) { create(:repository, :local) }

  describe "#perform" do
    it "calls Repositories::DiskSizeService" do
      allow(Repositories::DiskSizeService)
        .to receive(:new)
        .with(repository)
        .and_return service

      job.perform(repository)

      expect(service)
        .to have_received(:call)
    end

    context "when the repository's size was measured recently" do
      with_configuration "disk_size.interval" => 5

      let(:repository) { create(:repository, :local, disk_size_measured_at: 2.minutes.ago) }

      it "does not call Repositories::DiskSizeService" do
        allow(Repositories::DiskSizeService)
          .to receive(:new)
          .with(repository)
          .and_return service

        job.perform(repository)

        expect(service)
          .not_to have_received(:call)
      end

      context "when force is true" do
        it "calls Repositories::DiskSizeService" do
          allow(Repositories::DiskSizeService)
            .to receive(:new)
            .with(repository)
            .and_return service

          job.perform(repository, force: true)

          expect(service)
            .to have_received(:call)
        end
      end
    end
  end
end
