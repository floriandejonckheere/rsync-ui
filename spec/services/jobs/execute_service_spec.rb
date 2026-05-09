# frozen_string_literal: true

RSpec.describe Jobs::ExecuteService do
  subject(:service) { described_class.new(job_run) }

  let(:user) { create(:user) }
  let!(:notification) { create(:notification, user:) }
  let!(:job_notification) { create(:job_notification, job:, notification:) }
  let(:command_service) { instance_double(Rsync::CommandService, call: "rsync --recursive") }
  let(:job) { create(:job, user:, **options) }
  let(:job_run) { create(:job_run, :pending, job:, user:) }

  let(:options) { {} }

  let(:exit_status) { instance_double(Process::Status, success?: true, signaled?: false, exitstatus: 0) }
  let(:rsync_result) { Rsync::ExecuteService::Result.new(exit_status:, canceled: false) }
  let(:rsync_execute_service) { instance_double(Rsync::ExecuteService) }

  before do
    allow(Rsync::CommandService)
      .to receive(:new)
      .with(job:)
      .and_return(command_service)

    allow(Rsync::ExecuteService)
      .to receive(:new)
      .and_return(rsync_execute_service)

    allow(rsync_execute_service)
      .to receive(:call)
      .and_return(rsync_result)
  end

  describe "#call" do
    it "executes the job run" do
      service.call

      job_run.reload

      expect(job_run.trigger).to eq "manual"
      expect(job_run.user).to eq job.user
      expect(job_run).to be_completed
      expect(job_run.started_at).to be_present
      expect(job_run.completed_at).to be_present
      expect(job_run.output).to be_attached
    end

    context "when the job run is not pending" do
      before { job_run.update!(status: "running", started_at: Time.zone.now) }

      it "does not execute" do
        service.call

        expect(job_run.reload).to be_running
        expect(command_service).not_to have_received(:call)
      end
    end

    context "when the command exits with a non-zero status" do
      let(:exit_status) { instance_double(Process::Status, success?: false, signaled?: false, exitstatus: 1) }

      it "sets status to failed and completed_at" do
        service.call

        job_run.reload

        expect(job_run).to be_failed
        expect(job_run.completed_at).to be_present
        expect(job_run.output).to be_attached
      end
    end

    context "when a Ruby error is raised" do
      before do
        allow(command_service)
          .to receive(:call)
          .and_raise(RuntimeError, "something went wrong")
      end

      it "sets status to errored, error class, and message" do
        service.call

        job_run.reload

        expect(job_run).to be_errored
        expect(job_run.error_class).to eq "RuntimeError"
        expect(job_run.error_messages).to eq "something went wrong"
        expect(job_run.completed_at).to be_present
      end
    end

    context "when cancellation is requested" do
      let(:rsync_result) { Rsync::ExecuteService::Result.new(exit_status:, canceled: true) }

      before { job_run.update!(cancel_requested_at: Time.zone.now) }

      it "marks the job run as canceled" do
        service.call

        job_run.reload

        expect(job_run).to be_canceled
        expect(job_run.cancel_requested_at).to be_present
        expect(job_run.canceled_at).to be_present
        expect(job_run.completed_at).to be_present
        expect(job_run.output).to be_attached
      end
    end

    describe "progress tracking" do
      let(:status_line) { "  1,234,567  75%  10.00MB/s  0:00:10\r" }

      before do
        allow(rsync_execute_service)
          .to receive(:call)
          .and_yield(status_line)
          .and_return(rsync_result)
      end

      context "when only opt_progress is enabled" do
        let(:options) { { opt_progress: true, opt_progress2: false } }

        it "does not update bytes_copied and progress" do
          service.call

          job_run.reload

          expect(job_run.bytes_copied).to be_nil
          expect(job_run.progress).to be_nil
        end
      end

      context "when opt_progress2 is enabled" do
        let(:options) { { opt_progress: true, opt_progress2: true } }

        it "updates bytes_copied and progress" do
          service.call

          job_run.reload

          expect(job_run.bytes_copied).to eq 1_234_567
          expect(job_run.progress).to eq 75
        end
      end

      context "when opt_progress2 is disabled" do
        let(:options) { { opt_progress: true, opt_progress2: false } }

        it "writes the status line to the log" do
          service.call

          job_run.reload

          expect(job_run.bytes_copied).to be_nil
          expect(job_run.progress).to be_nil
          expect(job_run.output).to be_attached
        end
      end
    end

    describe "notifications" do
      with_configuration "notifications" => true

      it "enqueues a start notification when execution begins" do
        service.call
        job_run = job.job_runs.sole

        expect(Notifications::SendJob)
          .to have_been_enqueued
          .with(job_notification.id, job_run.id, "start")
      end

      it "enqueues a success notification when execution completes successfully" do
        service.call
        job_run = job.job_runs.sole

        expect(Notifications::SendJob)
          .to have_been_enqueued
          .with(job_notification.id, job_run.id, "success")
      end

      context "when notifications are disabled" do
        with_configuration "notifications" => false

        it "does not enqueue when notifications" do
          expect { service.call }
            .not_to have_enqueued_job(Notifications::SendJob)
        end
      end
    end

    describe "hooks" do
      with_configuration "hooks" => true

      context "when a pre-hook is configured" do
        before { create(:hook, :pre, job:, command: "echo", arguments: "pre", enabled: true) }

        it "executes the pre-hook before running the job" do
          service.call

          expect(job_run_for(job).pre_hook_output).to be_attached
        end
      end

      context "when the pre-hook fails" do
        before { create(:hook, :pre, job:, command: "false", enabled: true) }

        it "sets the job run status to errored and does not run rsync" do
          service.call

          job_run = job_run_for(job)

          expect(job_run).to be_errored
          expect(command_service).not_to have_received(:call)
        end
      end

      context "when a post-hook is configured" do
        before { create(:hook, :post, job:, command: "echo", arguments: "post", enabled: true) }

        it "executes the post-hook after running the job" do
          service.call

          expect(job_run_for(job).post_hook_output).to be_attached
        end
      end

      context "when a success-hook is configured" do
        before { create(:hook, :success, job:, command: "echo", arguments: "success", enabled: true) }

        it "executes the success-hook when the job completes successfully" do
          service.call

          expect(job_run_for(job).success_hook_output).to be_attached
        end

        context "when the job fails" do
          let(:exit_status) { instance_double(Process::Status, success?: false, signaled?: false, exitstatus: 1) }

          it "does not execute the success-hook" do
            service.call

            expect(job_run_for(job).success_hook_output).not_to be_attached
          end
        end
      end

      context "when a failure-hook is configured" do
        before { create(:hook, :failure, job:, command: "echo", arguments: "failure", enabled: true) }

        it "does not execute the failure-hook when the job succeeds" do
          service.call

          expect(job_run_for(job).failure_hook_output).not_to be_attached
        end

        context "when the job fails" do
          let(:exit_status) { instance_double(Process::Status, success?: false, signaled?: false, exitstatus: 1) }

          it "executes the failure-hook" do
            service.call

            expect(job_run_for(job).failure_hook_output).to be_attached
          end
        end
      end

      context "when hooks feature is disabled" do
        with_configuration "hooks" => false

        before { create(:hook, :pre, job:, command: "echo", arguments: "pre", enabled: true) }

        it "does not execute the pre-hook" do
          service.call

          expect(job_run_for(job).pre_hook_output).not_to be_attached
        end
      end
    end
  end

  def job_run_for(job)
    job.job_runs.sole
  end
end
