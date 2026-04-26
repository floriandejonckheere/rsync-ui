# frozen_string_literal: true

RSpec.describe JobRuns::ImportService do
  subject(:service) { described_class.new(path: tmp_path) }

  let(:tmp_path) { Pathname.new(Dir.mktmpdir) }
  let(:user) { create(:user) }
  let(:job) { create(:job, user:, name: "System backup") }

  after { FileUtils.remove_entry(tmp_path) }

  describe "#call" do
    context "when the CSV file exists" do
      before do
        user
        job

        tmp_path.join("05_job_runs.csv").write(<<~CSV)
          job_name,user_email,days_ago,trigger,status,started_at,completed_at
          System backup,#{user.email},2,scheduled,completed,02:00:00,02:04:32
          System backup,#{user.email},1,scheduled,completed,02:00:00,02:05:01
        CSV
      end

      it "keeps job runs separate across days" do
        travel_to Time.zone.local(2026, 4, 18, 12, 0, 0) do
          service.call
        end

        expect(JobRun.count).to eq(2)

        first = JobRun.find_by!(started_at: Time.zone.local(2026, 4, 16, 2, 0, 0))
        second = JobRun.find_by!(started_at: Time.zone.local(2026, 4, 17, 2, 0, 0))

        expect(first.completed_at).to eq(Time.zone.local(2026, 4, 16, 2, 4, 32))
        expect(second.completed_at).to eq(Time.zone.local(2026, 4, 17, 2, 5, 1))
      end
    end

    context "when the CSV file does not exist" do
      it "raises an error" do
        expect { service.call }
          .to raise_error ArgumentError
      end
    end
  end
end
