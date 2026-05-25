# frozen_string_literal: true

RSpec.describe JobRuns::CancelService do
  subject(:service) { described_class.new(job_run) }

  let(:user) { create(:user) }

  describe "#call" do
    context "when the job run is pending" do
      let(:job_run) { create(:job_run, :pending, user:) }

      it "transitions immediately to canceled" do
        result = service.call

        expect(result[:success]).to be true

        job_run.reload

        expect(job_run).to be_canceled
        expect(job_run.cancel_requested_at).to be_present
        expect(job_run.canceled_at).to be_present
        expect(job_run.completed_at).to be_present
      end

      it "does not enqueue CancelJob" do
        expect { service.call }.not_to have_enqueued_job(JobRuns::CancelJob)
      end
    end

    context "when the job run is running" do
      let(:job_run) { create(:job_run, :running, user:, pid: 12_345) }

      it "transitions to canceling and enqueues CancelJob" do
        expect { service.call }.to have_enqueued_job(JobRuns::CancelJob).with(job_run)

        job_run.reload

        expect(job_run).to be_canceling
        expect(job_run.cancel_requested_at).to be_present
        expect(job_run.canceled_at).to be_nil
      end

      it "returns success" do
        expect(service.call[:success]).to be true
      end
    end

    context "when the job run is already canceling" do
      let(:job_run) { create(:job_run, :canceling, user:) }

      it "returns failure" do
        expect(service.call[:success]).to be false
      end

      it "does not enqueue CancelJob" do
        expect { service.call }.not_to have_enqueued_job(JobRuns::CancelJob)
      end
    end

    context "when the job run is not cancelable" do
      let(:job_run) { create(:job_run, :completed, user:) }

      it "returns failure" do
        result = service.call

        expect(result[:success]).to be false
      end

      it "does not modify the job run" do
        expect { service.call }.not_to(change { job_run.reload.attributes })
      end
    end
  end
end
