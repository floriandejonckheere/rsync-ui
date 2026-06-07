# frozen_string_literal: true

RSpec.describe Jobs::ScheduleJobsService do
  subject(:service) { described_class.new }

  before { travel_to(Time.zone.local(2026, 4, 19, 2, 0, 30)) }

  let(:user) { create(:user) }

  describe "#call" do
    context "when a job has a cron schedule and has never run" do
      let!(:job) { create(:job, user:, schedule: "0 2 * * *") }

      it "creates a scheduled job run and enqueues execution" do
        service.call

        job_run = job.job_runs.sole

        expect(job_run.trigger).to eq "scheduled"
        expect(job_run).to be_pending

        expect(JobRuns::ExecuteJob)
          .to have_been_enqueued
          .with(job_run)
      end
    end

    context "when a job has a cron schedule and already ran in the current tick" do
      let!(:job) { create(:job, user:, schedule: "0 2 * * *") }

      it "does not create another job run" do
        create(:job_run, job:, user:, trigger: :scheduled, created_at: Time.zone.local(2026, 4, 19, 2, 0, 5))

        expect { service.call }
          .not_to(change { job.job_runs.count })
      end
    end

    context "when a job has a cron schedule and last ran before the current tick" do
      let!(:job) { create(:job, user:, schedule: "0 2 * * *") }

      it "creates a new scheduled job run" do
        create(:job_run, job:, user:, trigger: :scheduled, created_at: Time.zone.local(2026, 4, 18, 2, 0, 5))

        expect { service.call }
          .to change { job.job_runs.count }
          .by(1)
      end

      it "enqueues execution for the new job run" do
        service.call

        new_run = job.job_runs.order(:created_at).last

        expect(JobRuns::ExecuteJob)
          .to have_been_enqueued
          .with(new_run)
      end
    end

    context "when a job has no schedule" do
      it "does not create a job run" do
        create(:job, user:, schedule: nil)

        expect { service.call }
          .not_to have_enqueued_job(JobRuns::ExecuteJob)
      end
    end

    context "when a job has an invalid cron expression" do
      let!(:job) { create(:job, user:, schedule: "0 2 * * *") }

      it "does not create a job run and does not raise" do
        job.update_column(:schedule, "bogus") # rubocop:disable Rails/SkipsModelValidations

        expect { service.call }
          .not_to raise_error

        expect(job.job_runs).to be_empty
      end
    end

    context "when a job is disabled" do
      it "does not create a job run" do
        create(:job, user:, schedule: "0 2 * * *", enabled: false)

        expect { service.call }
          .not_to have_enqueued_job(JobRuns::ExecuteJob)
      end
    end
  end
end
