# frozen_string_literal: true

RSpec.describe SchedulerJob do
  before { travel_to(Time.zone.local(2026, 4, 19, 2, 0, 30)) }

  describe "job scheduling" do
    it "enqueues Jobs::ExecuteJob for due enabled jobs" do
      create(:job, schedule: "0 2 * * *", enabled: true)

      described_class.perform_now

      job_run = JobRun.sole
      expect(job_run).to be_pending
      expect(job_run.trigger).to eq "scheduled"
      expect(Jobs::ExecuteJob).to have_been_enqueued.with(job_run)
    end

    it "skips disabled jobs" do
      create(:job, schedule: "0 2 * * *", enabled: false)

      expect { described_class.perform_now }
        .not_to have_enqueued_job(Jobs::ExecuteJob)
    end

    it "skips jobs without a schedule" do
      create(:job, schedule: nil)

      expect { described_class.perform_now }
        .not_to have_enqueued_job(Jobs::ExecuteJob)
    end

    it "does not double-enqueue when a scheduled run already exists for the current tick" do
      job = create(:job, schedule: "0 2 * * *", enabled: true)
      create(:job_run, job:, user: job.user, trigger: :scheduled, created_at: Time.zone.local(2026, 4, 19, 2, 0, 5))

      expect { described_class.perform_now }
        .not_to have_enqueued_job(Jobs::ExecuteJob)
    end

    it "enqueues when the last scheduled run predates the current tick" do
      job = create(:job, schedule: "0 2 * * *", enabled: true)
      create(:job_run, job:, user: job.user, trigger: :scheduled, created_at: Time.zone.local(2026, 4, 18, 2, 0, 5))

      described_class.perform_now

      new_run = JobRun.order(:created_at).last
      expect(new_run).to be_pending
      expect(new_run.trigger).to eq "scheduled"
      expect(Jobs::ExecuteJob).to have_been_enqueued.with(new_run)
    end

    it "ignores jobs with an unparseable cron expression without raising" do
      job = create(:job, schedule: "0 2 * * *", enabled: true)
      job.update_column(:schedule, "bogus") # rubocop:disable Rails/SkipsModelValidations

      expect { described_class.perform_now }
        .not_to raise_error
    end

    context "when scheduler is disabled" do
      with_configuration "scheduler" => false

      it "does not enqueue any jobs" do
        create(:job, schedule: "0 2 * * *", enabled: true)

        expect { described_class.perform_now }
          .not_to have_enqueued_job(Jobs::ExecuteJob)
      end
    end
  end

  describe "connectivity scheduling" do
    with_configuration "connectivity" => true, "connectivity.interval" => 15

    let!(:never_probed) { create(:server, :with_password) }
    let!(:recent)       { create(:server, :with_password, probed_at: 2.minutes.ago) }
    let!(:stale)        { create(:server, :with_password, probed_at: 30.minutes.ago) }

    it "enqueues Servers::ConnectionJob for never-probed and stale servers" do
      expect { described_class.perform_now }
        .to have_enqueued_job(Servers::ConnectionJob)
        .exactly(2).times

      expect(Servers::ConnectionJob).to have_been_enqueued.with(never_probed)
      expect(Servers::ConnectionJob).to have_been_enqueued.with(stale)
      expect(Servers::ConnectionJob).not_to have_been_enqueued.with(recent)
    end

    context "when connectivity is disabled" do
      with_configuration "connectivity" => false

      it "does not enqueue any connectivity jobs" do
        expect { described_class.perform_now }
          .not_to have_enqueued_job(Servers::ConnectionJob)
      end
    end
  end

  describe "resource usage scheduling" do
    with_configuration "resource_usage" => true, "resource_usage.interval" => 15

    let!(:never_probed) { create(:server, :with_password) }
    let!(:recent) do
      create(:server, :with_password).tap { |s| create(:resource_usage, server: s, probed_at: 2.minutes.ago) }
    end
    let!(:stale) do
      create(:server, :with_password).tap { |s| create(:resource_usage, server: s, probed_at: 30.minutes.ago) }
    end

    it "enqueues Servers::ResourceUsageJob for never-probed and stale servers" do
      expect { described_class.perform_now }
        .to have_enqueued_job(Servers::ResourceUsageJob)
        .exactly(2).times

      expect(Servers::ResourceUsageJob).to have_been_enqueued.with(never_probed)
      expect(Servers::ResourceUsageJob).to have_been_enqueued.with(stale)
      expect(Servers::ResourceUsageJob).not_to have_been_enqueued.with(recent)
    end

    context "when resource_usage is disabled" do
      with_configuration "resource_usage" => false

      it "does not enqueue any resource usage jobs" do
        expect { described_class.perform_now }
          .not_to have_enqueued_job(Servers::ResourceUsageJob)
      end
    end
  end
end
