# frozen_string_literal: true

RSpec.describe Repositories::DiskSize::RemoteService do
  let(:service) { described_class.new(repository) }

  let(:repository) { create(:repository, :remote, server:, path: "/backups/my photos") }
  let(:server) { create(:server, :with_password) }

  describe "#call" do
    it "measures the size using du over SSH" do
      stub_ssh(output: "2048\t/backups/my photos\n")

      expect(service.call).to eq 2048 * 1024
    end

    it "runs du with an escaped path" do
      channel = stub_ssh(output: "2048\t/backups/my photos\n")

      service.call

      expect(channel).to have_received(:exec).with "du -sk /backups/my\\ photos"
    end

    context "when the output is unparseable" do
      it "raises an error" do
        stub_ssh(output: "du: /backups/my photos: No such file or directory\n")

        expect { service.call }.to raise_error(/unparseable du output/)
      end
    end
  end
end
