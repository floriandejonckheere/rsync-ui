# frozen_string_literal: true

RSpec.describe Jobs::ScheduleJob do
  subject(:perform) { described_class.new.perform }

  before { travel_to(Time.zone.local(2026, 4, 19, 2, 0, 30)) }

  it "enqueues Jobs::ExecuteJob for due enabled jobs" do
    job = create(:job, schedule: "0 2 * * *", enabled: true)

    expect { perform }
      .to have_enqueued_job(Jobs::ExecuteJob)
      .with(job, trigger: "scheduled")
  end

  it "skips disabled jobs" do
    create(:job, schedule: "0 2 * * *", enabled: false)

    expect { perform }
      .not_to have_enqueued_job Jobs::ExecuteJob
  end

  it "skips jobs without a schedule" do
    create(:job, schedule: nil)

    expect { perform }
      .not_to have_enqueued_job Jobs::ExecuteJob
  end

  it "does not double-enqueue when a scheduled run already exists for the current tick" do
    job = create(:job, schedule: "0 2 * * *", enabled: true)
    create(:job_run, job:, user: job.user, trigger: :scheduled, created_at: Time.zone.local(2026, 4, 19, 2, 0, 5))

    expect { perform }
      .not_to have_enqueued_job Jobs::ExecuteJob
  end

  it "enqueues when the last scheduled run predates the current tick" do
    job = create(:job, schedule: "0 2 * * *", enabled: true)
    create(:job_run, job:, user: job.user, trigger: :scheduled, created_at: Time.zone.local(2026, 4, 18, 2, 0, 5))

    expect { perform }
      .to have_enqueued_job(Jobs::ExecuteJob)
      .with(job, trigger: "scheduled")
  end

  it "ignores jobs with an unparseable cron expression without raising" do
    job = create(:job, schedule: "0 2 * * *", enabled: true)
    job.update_column(:schedule, "bogus") # rubocop:disable Rails/SkipsModelValidations

    expect { perform }
      .not_to raise_error
  end
end
