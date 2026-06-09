# frozen_string_literal: true

RSpec.describe JobRuns::CreateService do
  subject(:service) { described_class.new(job:, user:, trigger:) }

  let(:user) { create(:user) }
  let(:job) { create(:job, user:) }
  let(:trigger) { "manual" }

  let(:command_service) { instance_double(Rsync::CommandService, call: "rsync --archive /src/ /dst/") }

  before do
    allow(Rsync::CommandService)
      .to receive(:new)
      .with(job:)
      .and_return(command_service)
  end

  describe "#call" do
    it "creates a pending job run" do
      expect { service.call }
        .to change(JobRun, :count)
        .by(1)

      job_run = JobRun.last

      expect(job_run).to be_pending
      expect(job_run.job).to eq job
      expect(job_run.user).to eq user
      expect(job_run.trigger).to eq trigger
    end

    it "sets the command from Rsync::CommandService" do
      job_run = service.call

      expect(job_run.command).to eq "rsync --archive /src/ /dst/"

      expect(command_service)
        .to have_received(:call)
    end

    context "when trigger is scheduled" do
      let(:trigger) { "scheduled" }

      it "creates a scheduled job run" do
        job_run = service.call

        expect(job_run.trigger).to eq "scheduled"
      end
    end
  end
end
