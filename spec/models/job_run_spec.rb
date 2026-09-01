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
    it { is_expected.to validate_presence_of(:name) }
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

    it "enqueues a canceled notification on request_cancel from pending" do
      expect { job_run.request_cancel! }
        .to have_enqueued_job(Notifications::SendJob)
        .with(job_notification.id, job_run.id, "canceled")
    end

    it "enqueues a canceled notification on cancel" do
      job_run.update!(status: "running", started_at: Time.zone.now)
      job_run.request_cancel!

      expect { job_run.cancel! }
        .to have_enqueued_job(Notifications::SendJob)
        .with(job_notification.id, job_run.id, "canceled")
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

      it "does not enqueue a canceled notification on request_cancel" do
        expect { job_run.request_cancel! }
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
