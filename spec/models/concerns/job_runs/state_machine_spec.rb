# frozen_string_literal: true

RSpec.describe JobRuns::StateMachine do
  subject(:job_run) { build(:job_run) }

  describe "initial state" do
    it "starts as pending" do
      expect(JobRun.new).to be_pending
    end
  end

  describe "events" do
    describe "on start" do
      it "transitions from pending to running" do
        job_run = create(:job_run, :pending)

        expect { job_run.start! }
          .to change { job_run.reload.status }
          .from("pending").to("running")
      end
    end

    describe "on tick_progress" do
      it "does not transition" do
        job_run = create(:job_run, :running)

        expect { job_run.tick_progress!(bytes_copied: 1_000, progress: 50) }
          .not_to(change { job_run.reload.status })
      end
    end

    describe "on tick_status" do
      it "does not transition" do
        job_run = create(:job_run, :running)

        expect { job_run.tick_progress!(type: "log", content: "file.txt\n") }
          .not_to(change { job_run.reload.status })
      end
    end

    describe "on complete" do
      it "transitions from running to completed" do
        job_run = create(:job_run, :running)

        expect { job_run.complete! }
          .to change { job_run.reload.status }
          .from("running").to("completed")
      end
    end

    describe "on mark_failed" do
      it "transitions from running to failed" do
        job_run = create(:job_run, :running)

        expect { job_run.mark_failed! }
          .to change { job_run.reload.status }
          .from("running").to("failed")
      end
    end

    describe "on request_cancel" do
      it "transitions from pending to canceled" do
        job_run = create(:job_run, :pending)

        expect { job_run.request_cancel! }
          .to change { job_run.reload.status }
          .from("pending").to("canceled")
      end

      it "transitions from running to canceling" do
        job_run = create(:job_run, :running)

        expect { job_run.request_cancel! }
          .to change { job_run.reload.status }
          .from("running").to("canceling")
      end
    end

    describe "on cancel" do
      it "transitions from canceling to canceled" do
        job_run = create(:job_run, :canceling, cancel_requested_at: Time.zone.now)

        expect { job_run.cancel! }
          .to change { job_run.reload.status }
          .from("canceling").to("canceled")
      end
    end

    describe "on error" do
      it "transitions from pending to errored" do
        job_run = create(:job_run, :pending)

        expect { job_run.error! }
          .to change { job_run.reload.status }
          .from("pending").to("errored")
      end

      it "transitions from running to errored" do
        job_run = create(:job_run, :running)

        expect { job_run.error! }
          .to change { job_run.reload.status }
          .from("running").to("errored")
      end

      it "transitions from canceling to errored" do
        job_run = create(:job_run, :running, cancel_requested_at: Time.zone.now)
        job_run.update!(status: "canceling")

        expect { job_run.error! }
          .to change { job_run.reload.status }
          .from("canceling").to("errored")
      end

      it "does not allow error from completed" do
        job_run = create(:job_run, :completed)

        expect { job_run.error! }
          .to raise_error(StateMachines::InvalidTransition)
      end

      it "does not allow error from failed" do
        job_run = create(:job_run, :failed)

        expect { job_run.error! }
          .to raise_error(StateMachines::InvalidTransition)
      end

      it "does not allow error from canceled" do
        job_run = create(:job_run, :canceled)

        expect { job_run.error! }
          .to raise_error(StateMachines::InvalidTransition)
      end
    end
  end

  describe "callbacks" do
    describe "on start" do
      it "sets started_at" do
        job_run = create(:job_run, :pending)
        job_run.start!

        job_run.reload

        expect(job_run.started_at).to be_present
      end
    end

    describe "on tick_progress" do
      it "sets bytes_copied, progress, speed, and remaining_time" do
        job_run = create(:job_run, :running)
        job_run.tick_progress!(bytes_copied: 1_000, progress: 50, speed: 3_000, remaining_time: 120)

        job_run.reload

        expect(job_run.status).to eq "running"
        expect(job_run.bytes_copied).to eq 1_000
        expect(job_run.progress).to eq 50
        expect(job_run.speed).to eq 3_000
        expect(job_run.remaining_time).to eq 120
      end

      it "broadcasts the progress event through the throttler" do
        job_run = create(:job_run, :running)

        allow(JobRuns::BroadcastService).to receive(:broadcast_progress)

        job_run.tick_progress!(bytes_copied: 1_000, progress: 50)

        expect(JobRuns::BroadcastService).to have_received(:broadcast_progress).with(job_run)
      end
    end

    describe "on complete" do
      it "sets completed_at" do
        job_run = create(:job_run, :running)
        job_run.complete!

        job_run.reload

        expect(job_run.completed_at).to be_present
      end

      it "clears the output buffer" do
        job_run = create(:job_run, :running)
        Rails.cache.write(JobRuns::OutputBuffer.cache_key(job_run), "file.txt\n")

        job_run.complete!

        expect(JobRuns::OutputBuffer.read(job_run)).to eq ""
      end

      it "attaches any buffered output that was not already attached" do
        job_run = create(:job_run, :running)
        Rails.cache.write(JobRuns::OutputBuffer.cache_key(job_run), "file.txt\n")

        job_run.complete!

        expect(job_run.output).to be_attached
        expect(job_run.output.download).to eq "file.txt\n"
      end

      context "when disk_size is enabled" do
        with_configuration "disk_size" => true

        it "schedules a disk size job" do
          job_run = create(:job_run, :running)
          job_run.complete!

          expect(Repositories::DiskSizeJob)
            .to have_been_enqueued
            .with(job_run.job.destination_repository)
        end
      end
    end

    describe "on failed" do
      it "sets completed_at" do
        job_run = create(:job_run, :running)
        job_run.mark_failed!

        job_run.reload

        expect(job_run.completed_at).to be_present
      end

      context "when disk_size is enabled" do
        with_configuration "disk_size" => true

        it "schedules a disk size job" do
          job_run = create(:job_run, :running)
          job_run.complete!

          expect(Repositories::DiskSizeJob)
            .to have_been_enqueued
            .with(job_run.job.destination_repository)
        end
      end
    end

    describe "on request_cancel" do
      it "sets cancel_requested_at" do
        job_run = create(:job_run, :running)
        job_run.request_cancel!

        job_run.reload

        expect(job_run.cancel_requested_at).to be_present
        expect(job_run.canceled_at).to be_nil
        expect(job_run.completed_at).to be_nil
      end
    end

    describe "on cancel" do
      context "when cancel has been requested" do
        it "sets canceled_at and completed_at" do
          job_run = create(:job_run, :running, cancel_requested_at: Time.zone.now)
          job_run.update!(status: "canceling")
          job_run.cancel!

          job_run.reload

          expect(job_run.canceled_at).to be_present
          expect(job_run.completed_at).to be_present
        end
      end

      context "when job run is pending" do
        it "sets cancel_requested_at, canceled_at, and completed_at" do
          job_run = create(:job_run, :pending)
          job_run.request_cancel!

          job_run.reload

          expect(job_run.cancel_requested_at).to be_present
          expect(job_run.canceled_at).to be_present
          expect(job_run.completed_at).to be_present
        end

        it "does not overwrite existing cancel_requested_at" do
          cancel_requested_at = 1.minute.ago
          job_run = create(:job_run, :pending, cancel_requested_at:)
          job_run.request_cancel!

          job_run.reload

          expect(job_run.cancel_requested_at)
            .to be_within(1.second)
            .of(cancel_requested_at)
        end
      end

      context "when disk_size is enabled" do
        with_configuration "disk_size" => true

        it "schedules a disk size job" do
          job_run = create(:job_run, :running)
          job_run.complete!

          expect(Repositories::DiskSizeJob)
            .to have_been_enqueued
            .with(job_run.job.destination_repository)
        end
      end
    end

    describe "on error" do
      it "sets error_class, error_message, and completed_at" do
        job_run = create(:job_run, :running)
        job_run.error!(error_class: "RuntimeError", error_message: "boom")

        job_run.reload

        expect(job_run.error_class).to eq "RuntimeError"
        expect(job_run.error_message).to eq "boom"
        expect(job_run.completed_at).to be_present
      end

      context "when disk_size is enabled" do
        with_configuration "disk_size" => true

        it "schedules a disk size job" do
          job_run = create(:job_run, :running)
          job_run.complete!

          expect(Repositories::DiskSizeJob)
            .to have_been_enqueued
            .with(job_run.job.destination_repository)
        end
      end
    end
  end

  describe "predicates" do
    describe "#cancelable?" do
      it { expect(build(:job_run, :pending)).to be_cancelable }
      it { expect(build(:job_run, :running)).to be_cancelable }
      it { expect(build(:job_run, :canceling)).not_to be_cancelable }
      it { expect(build(:job_run, :completed)).not_to be_cancelable }
      it { expect(build(:job_run, :failed)).not_to be_cancelable }
      it { expect(build(:job_run, :canceled)).not_to be_cancelable }
      it { expect(build(:job_run, :errored)).not_to be_cancelable }
    end

    describe "#deletable?" do
      it { expect(build(:job_run, :completed)).to be_deletable }
      it { expect(build(:job_run, :failed)).to be_deletable }
      it { expect(build(:job_run, :canceled)).to be_deletable }
      it { expect(build(:job_run, :errored)).to be_deletable }
      it { expect(build(:job_run, :pending)).not_to be_deletable }
      it { expect(build(:job_run, :running)).not_to be_deletable }
      it { expect(build(:job_run, :canceling)).not_to be_deletable }
    end
  end
end
