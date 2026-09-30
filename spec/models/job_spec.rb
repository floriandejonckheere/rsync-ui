# frozen_string_literal: true

RSpec.describe Job do
  subject(:job) { build(:job) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:source_repository).class_name("Repository") }
    it { is_expected.to belong_to(:destination_repository).class_name("Repository") }

    it { is_expected.to have_many(:job_runs).dependent(:destroy) }
    it { is_expected.to have_many(:job_notifications).dependent(:destroy) }
    it { is_expected.to have_many(:notifications).through(:job_notifications) }
    it { is_expected.to have_many(:hooks).dependent(:destroy) }
    it { is_expected.to have_one(:pre_hook).conditions(hook_type: "pre").class_name("Hook").dependent(:destroy) }
    it { is_expected.to have_one(:post_hook).conditions(hook_type: "post").class_name("Hook").dependent(:destroy) }
    it { is_expected.to have_one(:success_hook).conditions(hook_type: "success").class_name("Hook").dependent(:destroy) }
    it { is_expected.to have_one(:failure_hook).conditions(hook_type: "failure").class_name("Hook").dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }

    it { is_expected.to define_enum_for(:ping_action).with_values(abort: "abort", cancel: "cancel").backed_by_column_of_type(:string).with_prefix(:ping) }

    it { is_expected.to validate_inclusion_of(:rsync_version).in_array(["latest", "3.5.1", "3.5.0", "3.4.4", "3.4.3", "3.4.2", "3.4.1", "3.4.0"]) }

    it "defaults to the latest rsync version" do
      expect(described_class.new.rsync_version).to eq("latest")
    end

    ["Dockerfile", "Dockerfile.prod"].each do |dockerfile|
      it "compiles every rsync version in #{dockerfile}" do
        versions = Rails.root.join(dockerfile).read[/^ARG RSYNC_VERSIONS="(.*)"$/, 1]

        expect(versions.split).to eq(described_class::RSYNC_VERSIONS)
      end
    end

    it "defaults to not pinging the servers" do
      expect(described_class.new).not_to be_ping
    end

    it "defaults to aborting when the servers are unreachable" do
      expect(described_class.new).to be_ping_abort
    end

    it "is invalid when the destination repository matches the source repository" do
      repository = build(:repository)

      job = build(:job, source_repository: repository, destination_repository: repository)

      expect(job).not_to be_valid
      expect(job.errors[:destination_repository]).to be_present
    end

    it "is invalid when both source and destination repositories are remote" do
      source_repository = build(:repository, :remote)
      destination_repository = build(:repository, :remote)

      job = build(:job, source_repository:, destination_repository:)

      expect(job).not_to be_valid
      expect(job.errors[:base]).to be_present
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

    it "is invalid with multiple delete timing options" do
      job = build(:job, opt_delete: true, opt_delete_before: true, opt_delete_after: true)

      expect(job).not_to be_valid
      expect(job.errors).to be_of_kind(:base, :multiple_delete_timings)
    end

    it "is valid with a single delete timing option" do
      job = build(:job, opt_delete: true, opt_delete_delay: true, opt_delete_excluded: true)

      expect(job).to be_valid
    end

    described_class::DELETE_OPTIONS.each do |option|
      it "is invalid with #{option} but without opt_delete" do
        job = build(:job, opt_delete: false, option => true)

        expect(job).not_to be_valid
        expect(job.errors).to be_of_kind(:base, :delete_required)
      end
    end
  end

  describe "TOGGLEABLE_OPTIONS" do
    it "contains every boolean rsync option exactly once" do
      boolean_options = described_class
        .columns
        .select { |c| c.name.start_with?("opt_") && c.type == :boolean }
        .map { |c| c.name.to_sym }

      expect(described_class::TOGGLEABLE_OPTIONS)
        .to match_array boolean_options
    end
  end

  describe "normalization" do
    it "strips surrounding whitespace from the category" do
      job = build(:job, category_name: "  Backups  ")

      job.valid?

      expect(job.category_name).to eq("Backups")
    end

    it "normalizes a blank category to nil" do
      job = build(:job, category_name: "   ")

      job.valid?

      expect(job.category_name).to be_nil
    end
  end

  describe "#local?" do
    it "returns true when both repositories are local" do
      job = build(:job, source_repository: build(:repository, :local), destination_repository: build(:repository, :local))

      expect(job.local?).to be(true)
    end

    it "returns false when the source repository is remote" do
      job = build(:job, source_repository: build(:repository, :remote), destination_repository: build(:repository, :local))

      expect(job.local?).to be(false)
    end

    it "returns false when the destination repository is remote" do
      job = build(:job, source_repository: build(:repository, :local), destination_repository: build(:repository, :remote))

      expect(job.local?).to be(false)
    end
  end

  describe "#remote?" do
    it "returns false when both repositories are local" do
      job = build(:job, source_repository: build(:repository, :local), destination_repository: build(:repository, :local))

      expect(job.remote?).to be(false)
    end

    it "returns true when the source repository is remote" do
      job = build(:job, source_repository: build(:repository, :remote), destination_repository: build(:repository, :local))

      expect(job.remote?).to be(true)
    end

    it "returns true when the destination repository is remote" do
      job = build(:job, source_repository: build(:repository, :local), destination_repository: build(:repository, :remote))

      expect(job.remote?).to be(true)
    end
  end

  describe "#remote_server" do
    it "returns nil when both repositories are local" do
      job = build(:job, source_repository: build(:repository, :local), destination_repository: build(:repository, :local))

      expect(job.remote_server).to be_nil
    end

    it "returns the server of the remote source repository" do
      source_repository = build(:repository, :remote)
      job = build(:job, source_repository:, destination_repository: build(:repository, :local))

      expect(job.remote_server).to eq source_repository.server
    end

    it "returns the server of the remote destination repository" do
      destination_repository = build(:repository, :remote)
      job = build(:job, source_repository: build(:repository, :local), destination_repository:)

      expect(job.remote_server).to eq destination_repository.server
    end
  end

  describe "#resolved_rsync_version" do
    it "resolves the latest rsync version to the most recent supported version" do
      job = build(:job, rsync_version: "latest")

      expect(job.resolved_rsync_version).to eq("3.5.1")
    end

    it "returns a specific rsync version as is" do
      job = build(:job, rsync_version: "3.4.1")

      expect(job.resolved_rsync_version).to eq("3.4.1")
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
