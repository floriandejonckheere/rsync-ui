# frozen_string_literal: true

RSpec.describe JobRuns::PurgeService do
  subject(:service) { described_class.new }

  with_configuration "job_runs.retention" => 31

  let!(:old_job_run) { create(:job_run, :completed, started_at: 32.days.ago) }
  let!(:recent_job_run) { create(:job_run, :completed, started_at: 30.days.ago) }

  before { old_job_run.output.attach(io: StringIO.new("log content"), filename: "output.log", content_type: "text/plain") }

  describe "#call" do
    it "removes job runs older than the retention period" do
      service.call

      expect(JobRun.exists?(old_job_run.id)).to be false
      expect(JobRun.exists?(recent_job_run.id)).to be true
    end

    it "purges attachments belonging to the removed job runs" do
      expect { service.call }
        .to have_enqueued_job(ActiveStorage::PurgeJob)
    end
  end
end
