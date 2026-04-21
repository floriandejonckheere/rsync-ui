# frozen_string_literal: true

RSpec.describe Job do
  subject(:job) { build(:job) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:source_repository).class_name("Repository") }
    it { is_expected.to belong_to(:destination_repository).class_name("Repository") }

    it { is_expected.to have_many(:job_runs).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }

    it "is invalid when the destination repository matches the source repository" do
      repository = build(:repository)
      job = build(:job, source_repository: repository, destination_repository: repository)

      expect(job).not_to be_valid
      expect(job.errors[:destination_repository]).to be_present
    end

    it "is invalid when the destination repository is read-only" do
      job = build(:job, destination_repository: build(:repository, read_only: true))

      expect(job).not_to be_valid
      expect(job.errors[:destination_repository]).to be_present
    end

    it "allows a blank schedule" do
      job = build(:job, schedule: nil)

      expect(job).to be_valid
    end

    it "is invalid with an invalid cron expression" do
      job = build(:job, schedule: "not a cron expression")

      expect(job).not_to be_valid
      expect(job.errors[:schedule]).to be_present
    end

    it "is valid with a cron expression" do
      job = build(:job, schedule: "0 2 * * *")

      expect(job).to be_valid
    end
  end

  describe "#scheduled_next_run" do
    it "returns nil when the job is disabled" do
      job = build(:job, schedule: "0 2 * * *", enabled: false)

      expect(job.scheduled_next_run).to be_nil
    end

    it "returns nil when no schedule is set" do
      job = build(:job, schedule: nil)

      expect(job.scheduled_next_run).to be_nil
    end

    it "returns the next tick of the cron expression" do
      travel_to(Time.zone.local(2026, 4, 19, 12, 0, 0)) do
        job = build(:job, schedule: "0 2 * * *", enabled: true)

        expect(job.scheduled_next_run).to eq(Time.zone.local(2026, 4, 20, 2, 0, 0))
      end
    end
  end
end
