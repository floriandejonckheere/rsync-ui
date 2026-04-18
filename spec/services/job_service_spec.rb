# frozen_string_literal: true

RSpec.describe JobService do
  subject(:service) { described_class.new(job, trigger: "manual") }

  let(:job) { create(:job) }
  let(:command_service) { instance_double(Rsync::CommandService, call: "echo rsync_output") }

  before do
    allow(Rsync::CommandService).to receive(:new).with(job:).and_return(command_service)
  end

  describe "#call" do
    it "creates a job run for the job" do
      expect { service.call }
        .to change(JobRun, :count).by(1)
    end

    it "sets the trigger on the job run" do
      service.call

      expect(JobRun.last.trigger).to eq "manual"
    end

    it "sets the user from the job" do
      service.call

      expect(JobRun.last.user).to eq job.user
    end

    it "transitions the job run to completed" do
      service.call

      expect(JobRun.last).to be_completed
    end

    it "sets started_at" do
      service.call

      expect(JobRun.last).to be_started_at
    end

    it "sets completed_at" do
      service.call

      expect(JobRun.last).to be_completed_at
    end

    it "attaches output to the job run" do
      service.call

      expect(JobRun.last.output).to be_attached
    end

    context "when the command exits with a non-zero status" do
      let(:command_service) { instance_double(Rsync::CommandService, call: "false") }

      it "sets status to failed" do
        service.call

        expect(JobRun.last).to be_failed
      end

      it "sets completed_at" do
        service.call

        expect(JobRun.last).to be_completed_at
      end

      it "still attaches output" do
        service.call

        expect(JobRun.last.output).to be_attached
      end
    end

    context "when a Ruby error is raised" do
      before do
        allow(command_service)
          .to receive(:call)
          .and_raise(RuntimeError, "something went wrong")
      end

      it "sets status to errored" do
        service.call

        expect(JobRun.last).to be_errored
      end

      it "records the error class" do
        service.call

        expect(JobRun.last.error_class).to eq "RuntimeError"
      end

      it "records the error message" do
        service.call

        expect(JobRun.last.error_messages).to eq "something went wrong"
      end

      it "sets completed_at" do
        service.call

        expect(JobRun.last).to be_completed_at
      end
    end
  end
end
