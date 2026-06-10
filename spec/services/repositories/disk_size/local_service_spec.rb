# frozen_string_literal: true

RSpec.describe Repositories::DiskSize::LocalService do
  let(:service) { described_class.new(repository) }

  let(:repository) { create(:repository, :local, path: "/data/photos") }

  describe "#call" do
    it "measures the size using du" do
      allow(Open3)
        .to receive(:capture3)
        .with("du", "-sk", "/data/photos")
        .and_return ["1024\t/data/photos\n", "", instance_double(Process::Status, success?: true)]

      expect(service.call).to eq 1024 * 1024
    end

    context "when du fails" do
      it "raises an error with stderr" do
        allow(Open3)
          .to receive(:capture3)
          .and_return ["", "du: /data/photos: No such file or directory\n", instance_double(Process::Status, success?: false)]

        expect { service.call }.to raise_error(/No such file or directory/)
      end
    end

    context "when du output is unparseable" do
      it "raises an error" do
        allow(Open3)
          .to receive(:capture3)
          .and_return ["garbage\n", "", instance_double(Process::Status, success?: true)]

        expect { service.call }.to raise_error(/unparseable du output/)
      end
    end
  end
end
