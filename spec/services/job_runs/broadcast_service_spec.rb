# frozen_string_literal: true

RSpec.describe JobRuns::BroadcastService do
  let(:user) { create(:user) }
  let(:job) { create(:job, user:) }

  before do
    allow(ActionCable.server).to receive(:broadcast)
    allow(Turbo::StreamsChannel).to receive(:broadcast_remove_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
  end

  describe ".broadcast_started" do
    let(:job_run) { create(:job_run, :running, job:, user:) }

    it "broadcasts the started event to the job run status channel" do
      described_class.broadcast_started(job_run)

      expect(ActionCable.server)
        .to have_received(:broadcast)
        .with(
          "job_run_status_#{job_run.id}",
          hash_including(type: "started", status: "running"),
        )
    end

    it "prepends the job run to the dashboard running list" do
      described_class.broadcast_started(job_run)

      expect(Turbo::StreamsChannel)
        .to have_received(:broadcast_prepend_to)
        .with("running_jobs_#{user.id}", hash_including(target: "running-job-runs"))
    end

    it "removes the empty state from the dashboard" do
      described_class.broadcast_started(job_run)

      expect(Turbo::StreamsChannel)
        .to have_received(:broadcast_remove_to)
        .with("running_jobs_#{user.id}", target: "running-jobs-empty")
    end
  end

  describe ".broadcast_progress" do
    let(:job_run) { create(:job_run, :running, job:, user:, progress: 42) }

    it "broadcasts the progress event to the job run status channel" do
      described_class.broadcast_progress(job_run)

      expect(ActionCable.server)
        .to have_received(:broadcast)
        .with(
          "job_run_status_#{job_run.id}",
          hash_including(type: "progress", progress: 42),
        )
    end
  end

  describe ".broadcast_status" do
    let(:job_run) { create(:job_run, :running, job:, user:, progress: 42) }

    describe "status event" do
      let(:type) { "status" }
      let(:content) { "  1,234,567  75%  10.00MB/s  0:00:10\r" }

      it "broadcasts the status event to the job run logs channel" do
        described_class.broadcast_status(job_run, type, content)

        expect(ActionCable.server)
          .to have_received(:broadcast)
          .with(
            "job_run_logs_#{job_run.id}",
            hash_including(type:, content:),
          )
      end
    end

    describe "log event" do
      let(:type) { "log" }
      let(:content) { "file.txt\n" }

      it "broadcasts the log event to the job run logs channel" do
        described_class.broadcast_status(job_run, type, content)

        expect(ActionCable.server)
          .to have_received(:broadcast)
          .with(
            "job_run_logs_#{job_run.id}",
            hash_including(type:, content:),
          )
      end
    end
  end

  describe ".broadcast_complete" do
    let(:job_run) { create(:job_run, :completed, job:, user:) }

    it "broadcasts the complete event to the job run status channel" do
      described_class.broadcast_complete(job_run)

      expect(ActionCable.server)
        .to have_received(:broadcast)
        .with(
          "job_run_status_#{job_run.id}",
          hash_including(type: "complete", status: "completed"),
        )
    end

    context "when transitioning from a live state" do
      it "removes the job run from the dashboard running list" do
        described_class.broadcast_complete(job_run, from: "running")

        expect(Turbo::StreamsChannel)
          .to have_received(:broadcast_remove_to)
          .with("running_jobs_#{user.id}", target: "running_job_run_#{job_run.id}")
      end

      context "when no other jobs are running" do
        it "appends the empty state to the dashboard" do
          described_class.broadcast_complete(job_run, from: "running")

          expect(Turbo::StreamsChannel)
            .to have_received(:broadcast_append_to)
            .with("running_jobs_#{user.id}", hash_including(target: "running-job-runs"))
        end
      end

      context "when other jobs are still running" do
        before { create(:job_run, :running, user:) }

        it "does not append the empty state" do
          described_class.broadcast_complete(job_run, from: "running")

          expect(Turbo::StreamsChannel).not_to have_received(:broadcast_append_to)
        end
      end
    end

    context "when transitioning from a terminal state (hook error after completion)" do
      it "does not touch the dashboard Turbo Stream" do
        described_class.broadcast_complete(job_run, from: "completed")

        expect(Turbo::StreamsChannel).not_to have_received(:broadcast_remove_to)
        expect(Turbo::StreamsChannel).not_to have_received(:broadcast_append_to)
      end
    end
  end
end
