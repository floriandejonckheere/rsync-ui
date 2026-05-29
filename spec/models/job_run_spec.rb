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
  end

  describe "state machine" do
    describe "initial state" do
      it "starts as pending" do
        expect(described_class.new).to be_pending
      end
    end

    describe "transitions" do
      it "transitions from pending to running on start" do
        job_run = create(:job_run, :pending)

        expect { job_run.start! }
          .to change { job_run.reload.status }
          .from("pending").to("running")
      end

      it "sets started_at when starting" do
        job_run = create(:job_run, :pending)
        job_run.start!

        expect(job_run.reload.started_at).to be_present
      end

      it "transitions from running to completed on complete" do
        job_run = create(:job_run, :running)

        expect { job_run.complete! }
          .to change { job_run.reload.status }
          .from("running").to("completed")
      end

      it "sets completed_at when completing" do
        job_run = create(:job_run, :running)
        job_run.complete!

        expect(job_run.reload.completed_at).to be_present
      end

      it "transitions from running to failed on mark_failed" do
        job_run = create(:job_run, :running)

        expect { job_run.mark_failed! }
          .to change { job_run.reload.status }
          .from("running").to("failed")
      end

      it "transitions from pending to canceled on request_cancel" do
        job_run = create(:job_run, :pending)

        expect { job_run.request_cancel! }
          .to change { job_run.reload.status }
          .from("pending").to("canceled")
      end

      it "transitions from running to canceling on request_cancel" do
        job_run = create(:job_run, :running)

        expect { job_run.request_cancel! }
          .to change { job_run.reload.status }
          .from("running").to("canceling")
      end

      it "sets cancel_requested_at but not canceled_at when canceling a running run" do
        job_run = create(:job_run, :running)
        job_run.request_cancel!
        job_run.reload

        expect(job_run.cancel_requested_at).to be_present
        expect(job_run.canceled_at).to be_nil
        expect(job_run.completed_at).to be_nil
      end

      it "transitions from canceling to canceled on cancel" do
        job_run = create(:job_run, :running, cancel_requested_at: Time.zone.now)
        job_run.update!(status: "canceling")

        expect { job_run.cancel! }
          .to change { job_run.reload.status }
          .from("canceling").to("canceled")
      end

      it "sets canceled_at and completed_at on cancel" do
        job_run = create(:job_run, :running, cancel_requested_at: Time.zone.now)
        job_run.update!(status: "canceling")
        job_run.cancel!

        job_run.reload

        expect(job_run.canceled_at).to be_present
        expect(job_run.completed_at).to be_present
      end

      it "sets cancel_requested_at, canceled_at, and completed_at when canceling a pending run" do
        job_run = create(:job_run, :pending)
        job_run.request_cancel!

        job_run.reload

        expect(job_run.cancel_requested_at).to be_present
        expect(job_run.canceled_at).to be_present
        expect(job_run.completed_at).to be_present
      end

      it "does not overwrite existing cancel_requested_at when canceling" do
        cancel_requested_at = 1.minute.ago
        job_run = create(:job_run, :pending, cancel_requested_at:)
        job_run.request_cancel!

        expect(job_run.reload.cancel_requested_at)
          .to be_within(1.second)
          .of(cancel_requested_at)
      end

      it "transitions from any live state to errored on error" do
        [:pending, :running].each do |state|
          job_run = create(:job_run, state)

          expect { job_run.error! }
            .to change { job_run.reload.status }
            .to("errored")
        end
      end

      it "transitions from canceling to errored on error" do
        job_run = create(:job_run, :running, cancel_requested_at: Time.zone.now)
        job_run.update!(status: "canceling")

        expect { job_run.error! }
          .to change { job_run.reload.status }
          .from("canceling").to("errored")
      end

      it "does not allow error from terminal states" do
        job_run = create(:job_run, :completed)

        expect { job_run.error! }
          .to raise_error(StateMachines::InvalidTransition)
      end

      it "accepts error_class and error_message arguments on error" do
        job_run = create(:job_run, :running)
        job_run.error!(error_class: "RuntimeError", error_message: "boom")
        job_run.reload

        expect(job_run.error_class).to eq "RuntimeError"
        expect(job_run.error_message).to eq "boom"
      end

      it "performs a loopback on tick and persists bytes_copied and progress" do
        job_run = create(:job_run, :running)
        job_run.tick!(bytes_copied: 1_000, progress: 50)
        job_run.reload

        expect(job_run.status).to eq "running"
        expect(job_run.bytes_copied).to eq 1_000
        expect(job_run.progress).to eq 50
      end

      it "raises on an invalid transition" do
        job_run = create(:job_run, :completed)

        expect { job_run.complete! }
          .to raise_error StateMachines::InvalidTransition
      end
    end

    describe "predicates" do
      describe "#deletable?" do
        it { expect(build(:job_run, :completed)).to be_deletable }
        it { expect(build(:job_run, :failed)).to be_deletable }
        it { expect(build(:job_run, :canceled)).to be_deletable }
        it { expect(build(:job_run, :errored)).to be_deletable }
        it { expect(build(:job_run, :pending)).not_to be_deletable }
        it { expect(build(:job_run, :running)).not_to be_deletable }
        it { expect(build(:job_run, :canceling)).not_to be_deletable }
      end

      describe "#cancelable?" do
        it { expect(build(:job_run, :pending)).to be_cancelable }
        it { expect(build(:job_run, :running)).to be_cancelable }
        it { expect(build(:job_run, :canceling)).not_to be_cancelable }
        it { expect(build(:job_run, :completed)).not_to be_cancelable }
        it { expect(build(:job_run, :failed)).not_to be_cancelable }
        it { expect(build(:job_run, :canceled)).not_to be_cancelable }
        it { expect(build(:job_run, :errored)).not_to be_cancelable }
      end
    end
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

  describe "notifications" do
    with_configuration "notifications" => true

    let(:user) { create(:user) }
    let(:job) { create(:job, user:) }
    let!(:notification) { create(:notification, user:) }
    let!(:job_notification) { create(:job_notification, job:, notification:) }

    let(:job_run) { create(:job_run, :pending, user:, job:) }

    it "enqueues a start notification on start" do
      expect { job_run.start! }
        .to have_enqueued_job(Notifications::SendJob)
        .with(job_notification.id, job_run.id, "start")
    end

    it "enqueues a success notification on complete" do
      job_run.update!(status: "running", started_at: Time.zone.now)

      expect { job_run.complete! }
        .to have_enqueued_job(Notifications::SendJob)
        .with(job_notification.id, job_run.id, "success")
    end

    it "enqueues a failure notification on mark_failed" do
      job_run.update!(status: "running", started_at: Time.zone.now)

      expect { job_run.mark_failed! }
        .to have_enqueued_job(Notifications::SendJob)
        .with(job_notification.id, job_run.id, "failure")
    end

    it "enqueues a failure notification on error" do
      expect { job_run.error!(error_class: "RuntimeError", error_message: "boom") }
        .to have_enqueued_job(Notifications::SendJob)
        .with(job_notification.id, job_run.id, "failure")
    end

    context "when notifications are disabled" do
      with_configuration "notifications" => false

      it "does not enqueue a start notification on start" do
        expect { job_run.start! }
          .not_to have_enqueued_job(Notifications::SendJob)
      end

      it "does not enqueue a success notification on complete" do
        job_run.update!(status: "running", started_at: Time.zone.now)

        expect { job_run.complete! }
          .not_to have_enqueued_job(Notifications::SendJob)
      end

      it "does not enqueue a failure notification on mark_failed" do
        job_run.update!(status: "running", started_at: Time.zone.now)

        expect { job_run.mark_failed! }
          .not_to have_enqueued_job(Notifications::SendJob)
      end

      it "does not enqueue a failure notification on error" do
        expect { job_run.error!(error_class: "RuntimeError", error_message: "boom") }
          .not_to have_enqueued_job(Notifications::SendJob)
      end
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
