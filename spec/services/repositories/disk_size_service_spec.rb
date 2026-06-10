# frozen_string_literal: true

RSpec.describe Repositories::DiskSizeService do
  let(:service) { described_class.new(repository) }

  describe "#call" do
    context "when the repository is local" do
      let(:repository) { create(:repository, :local) }

      it "measures the size using the local service" do
        allow(Repositories::DiskSize::LocalService)
          .to receive(:call)
          .with(repository)
          .and_return 2048

        service.call

        repository.reload

        expect(repository.disk_size).to eq 2048
        expect(repository.disk_size_status).to eq "ok"
        expect(repository.disk_size_error_class).to be_nil
        expect(repository.disk_size_error_message).to be_nil
        expect(repository.disk_size_measured_at).to be_within(5.seconds).of Time.zone.now
      end
    end

    context "when the repository is remote" do
      let(:repository) { create(:repository, :remote) }

      it "measures the size using the remote service" do
        allow(Repositories::DiskSize::RemoteService)
          .to receive(:call)
          .with(repository)
          .and_return 4096

        service.call

        repository.reload

        expect(repository.disk_size).to eq 4096
        expect(repository.disk_size_status).to eq "ok"
      end
    end

    context "when the measurement fails" do
      let(:repository) { create(:repository, :local, disk_size: 2048) }

      it "records status=failed with error details" do
        allow(Repositories::DiskSize::LocalService)
          .to receive(:call)
          .and_raise "du failed: permission denied"

        service.call

        repository.reload

        expect(repository.disk_size).to eq 2048
        expect(repository.disk_size_status).to eq "failed"
        expect(repository.disk_size_error_class).to eq "RuntimeError"
        expect(repository.disk_size_error_message).to include "permission denied"
        expect(repository.disk_size_measured_at).to be_within(5.seconds).of Time.zone.now
      end
    end
  end
end
