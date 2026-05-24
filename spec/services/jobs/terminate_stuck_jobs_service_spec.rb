# frozen_string_literal: true

RSpec.describe Jobs::TerminateStuckJobsService do
  subject(:service) { described_class.new }

  with_configuration "jobs.stuck_threshold" => 30

  let(:user) { create(:user) }
  let(:job) { create(:job, user:) }

  describe "#call" do
    context "with stuck running job runs" do
      context "when last_heartbeat_at is older than the threshold" do
        let!(:job_run) { create(:job_run, :running, job:, user:, last_heartbeat_at: 2.minutes.ago) }

        it "marks the job run as errored" do
          service.call

          job_run.reload

          expect(job_run).to be_errored
          expect(job_run.completed_at).to be_present
          expect(job_run.error_messages).to include "no heartbeat received for over 30 seconds"
        end
      end

      context "when last_heartbeat_at is nil and started_at is older than the threshold" do
        let!(:job_run) { create(:job_run, :running, job:, user:, last_heartbeat_at: nil, started_at: 2.minutes.ago) }

        it "marks the job run as errored" do
          service.call

          expect(job_run.reload).to be_errored
        end
      end

      context "when last_heartbeat_at is within the threshold" do
        let!(:job_run) { create(:job_run, :running, job:, user:, last_heartbeat_at: 10.seconds.ago) }

        it "does not modify the job run" do
          expect { service.call }.not_to(change { job_run.reload.attributes })
        end
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
          expect(job_run.error_messages).to include "no heartbeat received for over 30 seconds"
        end
      end

      context "when created_at is within the threshold" do
        let!(:job_run) { create(:job_run, :pending, job:, user:) }

        it "does not modify the job run" do
          expect { service.call }.not_to(change { job_run.reload.attributes })
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

    describe "notifications" do
      with_configuration "notifications" => true

      let!(:notification) { create(:notification, user:) }
      let!(:job_notification) { create(:job_notification, job:, notification:) }
      let!(:job_run) { create(:job_run, :running, job:, user:, last_heartbeat_at: 2.minutes.ago) }

      it "enqueues a failure notification for each job notification" do
        service.call

        expect(Notifications::SendJob)
          .to have_been_enqueued
          .with(job_notification.id, job_run.id, "failure")
      end

      context "when notifications are disabled" do
        with_configuration "notifications" => false

        it "does not enqueue notifications" do
          expect { service.call }.not_to have_enqueued_job Notifications::SendJob
        end
      end
    end
  end
end
