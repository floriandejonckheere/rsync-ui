# frozen_string_literal: true

RSpec.describe Jobs::ExecuteService do
  subject(:service) { described_class.new(job, trigger: "manual") }

  let(:user) { create(:user) }
  let(:job) { create(:job, user:) }

  let!(:notification) { create(:notification, user:) }
  let!(:job_notification) { create(:job_notification, job:, notification:) }

  let(:command_service) { instance_double(Rsync::CommandService, call: "echo rsync_output") }

  before do
    allow(Rsync::CommandService)
      .to receive(:new)
      .with(job:)
      .and_return(command_service)
  end

  describe "#call" do
    it "creates a job run for the job" do
      expect { service.call }
        .to change(JobRun, :count).by(1)

      job_run = JobRun.sole

      expect(job_run.trigger).to eq "manual"
      expect(job_run.user).to eq job.user
      expect(job_run).to be_completed
      expect(job_run).to be_started_at
      expect(job_run).to be_completed_at
      expect(job_run.output).to be_attached
    end

    context "when the command exits with a non-zero status" do
      let(:command_service) { instance_double(Rsync::CommandService, call: "false") }

      it "sets status to failed and completed_at" do
        service.call

        job_run = JobRun.sole

        expect(job_run).to be_failed
        expect(job_run).to be_completed_at
        expect(job_run.output).to be_attached
      end
    end

    context "when a Ruby error is raised" do
      before do
        allow(command_service)
          .to receive(:call)
          .and_raise(RuntimeError, "something went wrong")
      end

      it "sets status to errored, error class, and message" do
        service.call

        job_run = JobRun.sole

        expect(job_run).to be_errored
        expect(job_run.error_class).to eq "RuntimeError"
        expect(job_run.error_messages).to eq "something went wrong"
        expect(job_run).to be_completed_at
      end
    end

    describe "notifications" do
      with_configuration "notifications" => true

      it "enqueues a start notification when execution begins" do
        service.call
        job_run = job.job_runs.sole

        expect(Notifications::SendJob)
          .to have_been_enqueued
          .with(job_notification.id, job_run.id, "start")
      end

      it "enqueues a success notification when execution completes successfully" do
        service.call
        job_run = job.job_runs.sole

        expect(Notifications::SendJob)
          .to have_been_enqueued
          .with(job_notification.id, job_run.id, "success")
      end

      context "when notifications are disabled" do
        with_configuration "notifications" => false

        it "does not enqueue when notifications" do
          expect { service.call }
            .not_to have_enqueued_job(Notifications::SendJob)
        end
      end
    end
  end
end
