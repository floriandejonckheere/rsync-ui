# frozen_string_literal: true

RSpec.describe JobRuns::ExecuteService do
  subject(:service) { described_class.new(job_run) }

  let(:user) { create(:user) }
  let(:job) { create(:job, user:, **options) }
  let(:job_run) { create(:job_run, :pending, job:, user:) }

  let(:options) { {} }

  let(:rsync_result) { ExecutionResult.new(success: true, exit_status: 0) }
  let(:rsync_execute_service) { instance_double(Rsync::ExecuteService) }

  before do
    allow(Rsync::ExecuteService)
      .to receive(:new)
      .and_return(rsync_execute_service)

    allow(rsync_execute_service)
      .to receive(:call)
      .and_return(rsync_result)
  end

  describe "#call" do
    it "transitions to completed" do
      service.call

      job_run.reload

      expect(job_run.trigger).to eq "manual"
      expect(job_run.user).to eq job.user
      expect(job_run).to be_completed
      expect(job_run.started_at).to be_present
      expect(job_run.completed_at).to be_present
      expect(job_run.output).to be_attached
      expect(job_run.exit_status).to eq 0
    end

    context "when the job run is not pending" do
      before { job_run.update!(status: "running", started_at: Time.zone.now) }

      it "does not execute" do
        service.call

        job_run.reload

        expect(job_run).to be_running

        expect(rsync_execute_service)
          .not_to have_received(:call)
      end
    end

    context "when the command exits with a non-zero status" do
      let(:rsync_result) { ExecutionResult.new(success: false, exit_status: 1) }

      it "transitions to failed" do
        service.call

        job_run.reload

        expect(job_run).to be_failed
        expect(job_run.completed_at).to be_present
        expect(job_run.output).to be_attached
        expect(job_run.exit_status).to eq 1
      end
    end

    context "when a Ruby error is raised" do
      before do
        allow(rsync_execute_service)
          .to receive(:call)
          .and_raise(RuntimeError, "something went wrong")
      end

      it "transitions to errored" do
        service.call

        job_run.reload

        expect(job_run).to be_errored
        expect(job_run.error_class).to eq "RuntimeError"
        expect(job_run.error_message).to eq "something went wrong"
        expect(job_run.error_stacktrace).to be_present
        expect(job_run.completed_at).to be_present
      end
    end

    describe "cancellation" do
      let(:hook_exit_status) { instance_double(Process::Status, success?: true, signaled?: false, exitstatus: 0, termsig: nil) }
      let(:hook_result) { ExecutionResult.new(success: true, exit_status: hook_exit_status) }
      let(:hook_execute_service) { instance_double(Hooks::ExecuteService) }

      let(:job) { create(:job, :with_hooks, user:, **options) }

      before do
        allow(Hooks::ExecuteService)
          .to receive(:new)
          .and_return hook_execute_service

        allow(hook_execute_service)
          .to receive(:call)
          .and_return hook_result
      end

      context "when cancellation was requested during the pre-hook" do
        with_configuration "hooks" => true

        before do
          allow(hook_execute_service)
            .to receive(:call) do |&_block|
            job_run.request_cancel!

            hook_result
          end
        end

        it "transitions to canceled" do
          service.call

          job_run.reload

          expect(job_run).to be_canceled
          expect(job_run.cancel_requested_at).to be_present
          expect(job_run.canceled_at).to be_present
          expect(job_run.completed_at).to be_present
        end

        it "skips the rsync execution" do
          service.call

          expect(rsync_execute_service)
            .not_to have_received(:call)
        end

        it "skips the post-hook" do
          service.call

          expect(job_run.reload.post_hook_status).to be_nil
        end

        it "skips the success hook" do
          service.call

          expect(job_run.reload.success_hook_status).to be_nil
        end

        it "skips the failure hook" do
          service.call

          expect(job_run.reload.failure_hook_status).to be_nil
        end
      end

      context "when cancellation was requested during the rsync execution" do
        before do
          allow(rsync_execute_service)
            .to receive(:call) do |&_block|
            job_run.request_cancel!

            rsync_result
          end
        end

        it "transitions to canceled" do
          service.call

          job_run.reload

          expect(job_run).to be_canceled
          expect(job_run.cancel_requested_at).to be_present
          expect(job_run.canceled_at).to be_present
          expect(job_run.completed_at).to be_present
        end

        context "with hooks enabled" do
          with_configuration "hooks" => true

          it "skips the post-hook" do
            service.call

            expect(job_run.reload.post_hook_status).to be_nil
          end

          it "skips the success hook" do
            service.call

            expect(job_run.reload.success_hook_status).to be_nil
          end

          it "skips the failure hook" do
            service.call

            expect(job_run.reload.failure_hook_status).to be_nil
          end
        end
      end

      context "when cancellation was requested during the post-hook" do
        with_configuration "hooks" => true

        before do
          # Skip pre-hook so only the post-hook runs
          job_run.job.pre_hook.destroy!
          job_run.job.reload

          allow(hook_execute_service)
            .to receive(:call) do |&_block|
            job_run.request_cancel!

            hook_result
          end
        end

        it "transitions to canceled" do
          service.call

          job_run.reload

          expect(job_run).to be_canceled
          expect(job_run.cancel_requested_at).to be_present
          expect(job_run.canceled_at).to be_present
          expect(job_run.completed_at).to be_present
        end

        it "executes rsync" do
          service.call

          expect(rsync_execute_service)
            .to have_received(:call)
        end

        it "skips the success hook" do
          service.call

          expect(job_run.reload.success_hook_status).to be_nil
        end

        it "skips the failure hook" do
          service.call

          expect(job_run.reload.failure_hook_status).to be_nil
        end
      end
    end

    describe "progress tracking" do
      let(:status_line) { "  1,234,567  75%  10.00MB/s  0:00:10\r" }

      before do
        allow(rsync_execute_service)
          .to receive(:call)
          .and_yield(status_line)
          .and_return rsync_result
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

        it "updates bytes_copied and progress and writes the last status line to the log" do
          service.call

          job_run.reload

          expect(job_run.bytes_copied).to eq 1_234_567
          expect(job_run.progress).to eq 75
          expect(job_run.output.download).to include status_line
        end
      end

      context "when opt_progress2 is disabled" do
        let(:options) { { opt_progress: true, opt_progress2: false } }

        it "writes the status line to the log" do
          service.call

          job_run.reload

          expect(job_run.bytes_copied).to be_nil
          expect(job_run.progress).to be_nil
          expect(job_run.output.download).to include status_line
        end
      end
    end

    describe "hooks" do
      with_configuration "hooks" => true

      let(:pre_hook) { create(:hook, :pre, command: "echo", arguments: "running pre-hook") }
      let(:post_hook) { create(:hook, :post, command: "echo", arguments: "running post-hook") }
      let(:success_hook) { create(:hook, :success, command: "echo", arguments: "running success hook") }
      let(:failure_hook) { create(:hook, :failure, command: "echo", arguments: "running failure hook") }
      let(:job) { create(:job, :with_hooks, pre_hook:, post_hook:, success_hook:, failure_hook:, user:, **options) }

      describe "pre-hook" do
        it "executes the pre-hook before running rsync" do
          service.call

          job_run.reload

          expect(job_run.pre_hook_status).to eq "success"
          expect(job_run.pre_hook_exit_status).to eq 0
          expect(job_run.pre_hook_output.download).to include "running pre-hook"
        end

        it "executes the success hook" do
          service.call

          job_run.reload

          expect(job_run.success_hook_status).to eq "success"
          expect(job_run.success_hook_exit_status).to eq 0
          expect(job_run.success_hook_output.download).to include "running success hook"
        end

        it "skips the failure hook" do
          service.call

          expect(job_run.reload.failure_hook_status).to be_nil
        end

        context "when the pre-hook is disabled" do
          let(:pre_hook) { create(:hook, :pre, command: "echo", arguments: "running pre-hook", enabled: false) }

          it "does not execute the pre-hook" do
            service.call

            expect(job_run.pre_hook_status).to be_nil
            expect(job_run.pre_hook_exit_status).to be_nil
            expect(job_run.pre_hook_output).not_to be_attached
          end
        end

        context "when the pre-hook fails" do
          let(:pre_hook) { create(:hook, :pre, command: "false", arguments: nil) }

          it "transitions to failed" do
            service.call

            job_run.reload

            expect(job_run).to be_failed
            expect(job_run.pre_hook_status).to eq "failed"
            expect(job_run.pre_hook_exit_status).to eq 1
          end

          it "skips rsync" do
            service.call

            expect(rsync_execute_service)
              .not_to have_received(:call)
          end

          it "skips the success hook" do
            service.call

            expect(job_run.reload.success_hook_status).to be_nil
          end

          it "executes the failure hook" do
            service.call

            job_run.reload

            expect(job_run.failure_hook_status).to eq "success"
            expect(job_run.failure_hook_exit_status).to eq 0
            expect(job_run.failure_hook_output.download).to include "running failure hook"
          end
        end
      end

      describe "post-hook" do
        it "executes the post-hook after running rsync" do
          service.call

          job_run.reload

          expect(job_run.post_hook_status).to eq "success"
          expect(job_run.post_hook_exit_status).to eq 0
          expect(job_run.post_hook_output.download).to include "running post-hook"
        end

        it "executes the success hook" do
          service.call

          job_run.reload

          expect(job_run.success_hook_status).to eq "success"
          expect(job_run.success_hook_exit_status).to eq 0
          expect(job_run.success_hook_output.download).to include "running success hook"
        end

        it "skips the failure hook" do
          service.call

          expect(job_run.reload.failure_hook_status).to be_nil
        end

        context "when the post-hook is disabled" do
          let(:post_hook) { create(:hook, :post, command: "echo", arguments: "running post-hook", enabled: false) }

          it "does not execute the post-hook" do
            service.call

            expect(job_run.post_hook_status).to be_nil
            expect(job_run.post_hook_exit_status).to be_nil
            expect(job_run.post_hook_output).not_to be_attached
          end
        end

        context "when the post-hook fails" do
          let(:post_hook) { create(:hook, :post, command: "false", arguments: nil) }

          it "transitions to failed" do
            service.call

            job_run.reload

            expect(job_run).to be_failed
            expect(job_run.post_hook_status).to eq "failed"
            expect(job_run.post_hook_exit_status).to eq 1
          end

          it "skips the success hook" do
            service.call

            expect(job_run.reload.success_hook_status).to be_nil
          end

          it "executes the failure hook" do
            service.call

            job_run.reload

            expect(job_run.failure_hook_status).to eq "success"
            expect(job_run.failure_hook_exit_status).to eq 0
            expect(job_run.failure_hook_output.download).to include "running failure hook"
          end
        end
      end

      describe "success hook" do
        context "when rsync exits successfully" do
          it "executes the success hook" do
            service.call

            job_run.reload

            expect(job_run.success_hook_status).to eq "success"
            expect(job_run.success_hook_exit_status).to eq 0
            expect(job_run.success_hook_output.download).to include "running success hook"
          end

          context "when the success hook is disabled" do
            let(:success_hook) { create(:hook, :success, command: "echo", arguments: "running success hook", enabled: false) }

            it "does not execute the success hook" do
              service.call

              expect(job_run.success_hook_status).to be_nil
              expect(job_run.success_hook_exit_status).to be_nil
              expect(job_run.success_hook_output).not_to be_attached
            end
          end

          context "when the success hook fails" do
            let(:success_hook) { create(:hook, :success, command: "false", arguments: nil) }

            it "transitions to failed" do
              service.call

              job_run.reload

              expect(job_run).to be_failed
              expect(job_run.success_hook_status).to eq "failed"
              expect(job_run.success_hook_exit_status).to eq 1
            end

            it "executes the failure hook" do
              service.call

              job_run.reload

              expect(job_run.failure_hook_status).to eq "success"
              expect(job_run.failure_hook_exit_status).to eq 0
              expect(job_run.failure_hook_output.download).to include "running failure hook"
            end
          end
        end

        context "when rsync fails" do
          let(:rsync_result) { ExecutionResult.new(success: false, exit_status: 1) }

          it "skips the success hook" do
            service.call

            job_run.reload

            expect(job_run.reload.success_hook_status).to be_nil
          end
        end
      end

      describe "failure hook" do
        context "when rsync exits successfully" do
          it "skips the failure hook" do
            service.call

            job_run.reload

            expect(job_run.reload.failure_hook_status).to be_nil
          end
        end

        context "when rsync fails" do
          let(:rsync_result) { ExecutionResult.new(success: false, exit_status: 1) }

          it "executes the failure hook" do
            service.call

            job_run.reload

            expect(job_run.failure_hook_status).to eq "success"
            expect(job_run.failure_hook_exit_status).to eq 0
            expect(job_run.failure_hook_output.download).to include "running failure hook"
          end

          context "when the failure hook is disabled" do
            let(:failure_hook) { create(:hook, :failure, command: "echo", arguments: "running failure hook", enabled: false) }

            it "does not execute the failure hook" do
              service.call

              expect(job_run.failure_hook_status).to be_nil
              expect(job_run.failure_hook_exit_status).to be_nil
              expect(job_run.failure_hook_output).not_to be_attached
            end
          end

          context "when the failure hook fails" do
            let(:failure_hook) { create(:hook, :failure, command: "false", arguments: nil) }

            it "transitions to failed" do
              service.call

              job_run.reload

              expect(job_run).to be_failed
              expect(job_run.failure_hook_status).to eq "failed"
              expect(job_run.failure_hook_exit_status).to eq 1
            end
          end
        end
      end

      context "when hooks feature is disabled" do
        with_configuration "hooks" => false

        it "skips all hooks" do
          service.call

          job_run.reload

          expect(job_run.pre_hook_status).to be_nil
          expect(job_run.post_hook_status).to be_nil
          expect(job_run.success_hook_status).to be_nil
          expect(job_run.failure_hook_status).to be_nil
        end
      end
    end

    describe "streaming" do
      with_configuration "streaming" => true

      let(:line) { "file.txt\n" }

      before do
        allow(ActionCable.server)
          .to receive(:broadcast)

        allow(Turbo::StreamsChannel)
          .to receive(:broadcast_remove_to)

        allow(Turbo::StreamsChannel)
          .to receive(:broadcast_prepend_to)

        allow(Turbo::StreamsChannel)
          .to receive(:broadcast_append_to)

        allow(rsync_execute_service)
          .to receive(:call)
          .and_yield(line)
          .and_return(rsync_result)
      end

      it "broadcasts the started event to the status channel" do
        service.call

        expect(ActionCable.server)
          .to have_received(:broadcast)
          .with "job_run_status_#{job_run.id}", hash_including(type: "started", status: "running")
      end

      it "broadcasts the complete event to the status channel" do
        service.call

        expect(ActionCable.server)
          .to have_received(:broadcast)
          .with "job_run_status_#{job_run.id}", hash_including(type: "complete", status: "completed")
      end

      it "broadcasts log lines to the logs channel" do
        service.call

        expect(ActionCable.server)
          .to have_received(:broadcast)
          .with "job_run_logs_#{job_run.id}", { type: "log", content: line }
      end

      it "buffers the output so it can be fetched while the job run is in progress" do
        output_buffer = instance_double(JobRuns::OutputBuffer, :<< => nil, flush: nil)

        allow(JobRuns::OutputBuffer)
          .to receive(:new)
          .and_return(output_buffer)

        service.call

        expect(output_buffer)
          .to have_received(:<<)
          .with(line)

        expect(output_buffer)
          .to have_received(:flush)
      end

      context "when line matches status pattern and opt_progress2 is enabled" do
        let(:line) { "  1,234,567  75%  10.00MB/s  0:00:10\r" }
        let(:options) { { opt_progress: true, opt_progress2: true } }

        it "broadcasts the line as a status message to the logs channel" do
          service.call

          expect(ActionCable.server)
            .to have_received(:broadcast)
            .with "job_run_logs_#{job_run.id}", { type: "status", content: line }
        end

        it "broadcasts the progress event to the status channel" do
          service.call

          expect(ActionCable.server)
            .to have_received(:broadcast)
            .with "job_run_status_#{job_run.id}", hash_including(type: "progress", progress: 75)
        end
      end

      context "when streaming is disabled" do
        with_configuration "streaming" => false

        it "does not broadcast" do
          service.call

          expect(ActionCable.server)
            .not_to have_received :broadcast
        end

        it "does not buffer output" do
          allow(JobRuns::OutputBuffer)
            .to receive(:new)

          service.call

          expect(JobRuns::OutputBuffer)
            .not_to have_received(:new)
        end
      end

      context "when the pre-hook fails" do
        with_configuration "hooks" => true

        let(:pre_hook) { create(:hook, :pre, command: "false", arguments: nil) }
        let(:job) { create(:job, :with_hooks, pre_hook:, user:, **options) }

        it "broadcasts completion with failed status to the status channel" do
          service.call

          expect(ActionCable.server)
            .to have_received(:broadcast)
            .with "job_run_status_#{job_run.id}", hash_including(type: "complete", status: "failed")
        end
      end

      context "when rsync fails" do
        with_configuration "hooks" => true

        let(:rsync_result) { ExecutionResult.new(success: false, exit_status: 1) }

        it "broadcasts completion with failed status to the status channel" do
          service.call

          expect(ActionCable.server)
            .to have_received(:broadcast)
            .with "job_run_status_#{job_run.id}", hash_including(type: "complete", status: "failed")
        end
      end

      context "when the post-hook fails" do
        with_configuration "hooks" => true

        let(:post_hook) { create(:hook, :post, command: "false", arguments: nil) }
        let(:job) { create(:job, :with_hooks, post_hook:, user:, **options) }

        it "broadcasts completion with failed status to the status channel" do
          service.call

          expect(ActionCable.server)
            .to have_received(:broadcast)
            .with "job_run_status_#{job_run.id}", hash_including(type: "complete", status: "failed")
        end
      end

      context "when the success hook fails" do
        with_configuration "hooks" => true

        let(:success_hook) { create(:hook, :success, command: "false", arguments: nil) }
        let(:job) { create(:job, :with_hooks, success_hook:, user:, **options) }

        it "broadcasts completion with failed status to the status channel" do
          service.call

          expect(ActionCable.server)
            .to have_received(:broadcast)
            .with "job_run_status_#{job_run.id}", hash_including(type: "complete", status: "failed")
        end
      end

      context "when the failure hook fails" do
        with_configuration "hooks" => true

        let(:rsync_result) { ExecutionResult.new(success: false, exit_status: 1) }
        let(:failure_hook) { create(:hook, :failure, command: "false", arguments: nil) }
        let(:job) { create(:job, :with_hooks, failure_hook:, user:, **options) }

        it "broadcasts completion with failed status to the status channel" do
          service.call

          expect(ActionCable.server)
            .to have_received(:broadcast)
            .with "job_run_status_#{job_run.id}", hash_including(type: "complete", status: "failed")
        end
      end

      context "when a Ruby error is raised" do
        before do
          allow(rsync_execute_service)
            .to receive(:call)
            .and_raise(RuntimeError, "boom")
        end

        it "broadcasts completion with errored status to the status channel" do
          service.call

          expect(ActionCable.server)
            .to have_received(:broadcast)
            .with "job_run_status_#{job_run.id}", hash_including(type: "complete", status: "errored")
        end
      end
    end
  end
end
