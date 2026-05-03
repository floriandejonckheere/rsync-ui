# frozen_string_literal: true

RSpec.describe Jobs::CancelService do
  subject(:service) { described_class.new(job_run) }

  let(:user) { create(:user) }

  describe "#call" do
    context "when the job run is pending" do
      let(:job_run) { create(:job_run, :pending, user:) }

      it "cancels the job run immediately" do
        result = service.call

        expect(result[:success]).to be true

        job_run.reload

        expect(job_run).to be_canceled
        expect(job_run.cancel_requested_at).to be_present
        expect(job_run.canceled_at).to be_present
        expect(job_run.completed_at).to be_present
      end
    end

    context "when the job run is running" do
      let(:job_run) { create(:job_run, :running, user:, pid: 12_345) }

      it "requests cancellation" do
        result = service.call

        expect(result[:success]).to be true

        job_run.reload

        expect(job_run).to be_running
        expect(job_run.cancel_requested_at).to be_present
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
