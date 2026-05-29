# frozen_string_literal: true

RSpec.describe Jobs::TerminateStuckJobsService do
  subject(:service) { described_class.new }

  with_configuration "jobs.stuck_threshold" => 30

  let(:user) { create(:user) }
  let(:job) { create(:job, user:) }

  describe "#call" do
    context "with a running job whose pid is dead" do
      let!(:job_run) { create(:job_run, :running, job:, user:, pid: 99_999) }

      before do
        allow(Process)
          .to receive(:kill)
          .with(0, -99_999)
          .and_raise Errno::ESRCH
      end

      it "marks the job run as errored" do
        service.call

        job_run.reload

        expect(job_run).to be_errored
        expect(job_run.completed_at).to be_present
        expect(job_run.error_message).to include("Worker")
      end
    end

    context "with a running job whose pid is alive" do
      let!(:job_run) { create(:job_run, :running, job:, user:, pid: 99_999) }

      before do
        allow(Process)
          .to receive(:kill)
          .with(0, -99_999)
          .and_return 1
      end

      it "does not modify the job run" do
        expect { service.call }
          .not_to(change { job_run.reload.attributes })
      end
    end

    context "with a running job whose pid is nil and inside the grace window" do
      let!(:job_run) { create(:job_run, :running, job:, user:, pid: nil) }

      it "does not modify the job run" do
        expect { service.call }
          .not_to(change { job_run.reload.attributes })
      end
    end

    context "with a running job whose pid is nil and past the grace window" do
      let!(:job_run) { create(:job_run, :running, job:, user:, pid: nil, updated_at: 5.minutes.ago) }

      it "marks the job run as errored" do
        service.call

        expect(job_run.reload).to be_errored
      end
    end

    context "with a canceling job whose pid is dead" do
      let!(:job_run) { create(:job_run, :canceling, job:, user:, pid: 99_999) }

      before do
        allow(Process)
          .to receive(:kill)
          .with(0, -99_999)
          .and_raise Errno::ESRCH
      end

      it "transitions canceling to canceled" do
        service.call

        job_run.reload

        expect(job_run).to be_canceled
        expect(job_run.canceled_at).to be_present
      end
    end

    context "with a canceling job whose pid is alive" do
      let!(:job_run) { create(:job_run, :canceling, job:, user:, pid: 99_999) }

      before do
        allow(Process)
          .to receive(:kill)
          .with(0, -99_999)
          .and_return 1
      end

      it "does not modify the job run" do
        expect { service.call }
          .not_to(change { job_run.reload.attributes })
      end
    end

    context "with stuck pending job runs" do
      context "when created_at is older than the threshold" do
        let!(:job_run) { create(:job_run, :pending, job:, user:, created_at: 2.minutes.ago) }

        it "marks the job run as errored" do
          service.call

          job_run.reload

          expect(job_run).to be_errored
          expect(job_run.completed_at).to be_present
        end
      end

      context "when created_at is within the threshold" do
        let!(:job_run) { create(:job_run, :pending, job:, user:) }

        it "does not modify the job run" do
          expect { service.call }
            .not_to(change { job_run.reload.attributes })
        end
      end
    end

    context "with completed, failed, or canceled job runs older than the threshold" do
      let!(:completed_run) { create(:job_run, :completed, job:, user:) }
      let!(:failed_run) { create(:job_run, :failed, job:, user:) }
      let!(:canceled_run) { create(:job_run, :canceled, job:, user:) }

      it "does not modify them" do
        expect { service.call }
          .not_to(change { [completed_run, failed_run, canceled_run].map { it.reload.attributes } })
      end
    end
  end
end
