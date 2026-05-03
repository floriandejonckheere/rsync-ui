# frozen_string_literal: true

RSpec.describe JobRun do
  subject(:job_run) { build(:job_run) }

  describe "associations" do
    it { is_expected.to belong_to(:job) }
    it { is_expected.to belong_to(:user) }

    it { is_expected.to have_one_attached(:output) }
    it { is_expected.to have_one_attached(:pre_hook_output) }
    it { is_expected.to have_one_attached(:post_hook_output) }
    it { is_expected.to have_one_attached(:success_hook_output) }
    it { is_expected.to have_one_attached(:failure_hook_output) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:trigger) }
    it { is_expected.to validate_presence_of(:status) }
  end

  describe "enums" do
    it "defines an enum for trigger" do
      expect(job_run)
        .to define_enum_for(:trigger)
        .with_values(manual: "manual", scheduled: "scheduled")
        .backed_by_column_of_type(:string)
    end

    it "defines an enum for status" do
      expect(job_run)
        .to define_enum_for(:status)
        .with_values(pending: "pending", running: "running", completed: "completed", failed: "failed", canceled: "canceled", errored: "errored")
        .backed_by_column_of_type(:string)
    end
  end

  describe "#deletable?" do
    it { expect(build(:job_run, :completed)).to be_deletable }
    it { expect(build(:job_run, :failed)).to be_deletable }
    it { expect(build(:job_run, :canceled)).to be_deletable }
    it { expect(build(:job_run, :errored)).to be_deletable }
    it { expect(build(:job_run, :pending)).not_to be_deletable }
    it { expect(build(:job_run, :running)).not_to be_deletable }
  end

  describe "#duration" do
    it "returns nil when started_at is blank" do
      job_run = build(:job_run, started_at: nil)

      expect(job_run.duration).to be_nil
    end

    it "returns elapsed seconds since started_at when running" do
      job_run = build(:job_run, :running, started_at: 5.minutes.ago, completed_at: nil)

      expect(job_run.duration).to be_within(1).of(5.minutes.to_i)
    end

    it "returns seconds from started_at to completed_at when completed" do
      job_run = build(:job_run, :completed, started_at: 10.minutes.ago, completed_at: 5.minutes.ago)

      expect(job_run.duration).to be_within(1).of(5.minutes.to_i)
    end
  end

  describe "sequence" do
    it "is assigned automatically by the database on create" do
      job_run = create(:job_run)

      expect(job_run.sequence).to be_present
    end

    it "is globally incrementing across job runs" do
      first = create(:job_run)
      second = create(:job_run)

      expect(second.sequence).to be > first.sequence
    end
  end
end
