# frozen_string_literal: true

RSpec.describe Hooks::ExecuteService do
  subject(:service) { described_class.new(hook, job_run:) }

  let(:user) { create(:user) }
  let(:job) { create(:job, user:) }
  let(:hook) { create(:hook, :pre, job:, command: "echo", arguments: "hello {job_name}") }
  let(:job_run) do
    create(:job_run, job:, user:, trigger: "manual", status: "running", started_at: Time.zone.now, sequence: 1)
  end

  describe "#call" do
    it "returns a successful result and persists per-hook status" do
      result = service.call

      expect(result.success).to be true
      expect(result.exit_status).to eq 0

      job_run.reload

      expect(job_run.pre_hook_status).to eq("success")
      expect(job_run.pre_hook_exit_status).to eq(0)
      expect(job_run.pre_hook_error_class).to be_nil
      expect(job_run.pre_hook_error_message).to be_nil
    end

    it "attaches the hook output to the job run" do
      service.call

      expect(job_run.pre_hook_output).to be_attached
    end

    it "interpolates job_name into arguments" do
      allow(Open3).to receive(:popen2e).and_call_original

      service.call

      expect(Open3)
        .to have_received(:popen2e)
        .with("echo hello #{job.name}", pgroup: true)
    end

    context "when the command exits with a non-zero status" do
      let(:hook) { create(:hook, :pre, job:, command: "false") }

      it "returns a failed result and persists per-hook status" do
        result = service.call

        expect(result.success).to be false
        expect(result.exit_status).to eq 1

        job_run.reload

        expect(job_run.pre_hook_status).to eq("failed")
        expect(job_run.pre_hook_exit_status).to eq(1)
        expect(job_run.pre_hook_output).to be_attached
      end
    end

    context "when a Ruby error is raised" do
      before do
        allow(Open3)
          .to receive(:popen2e)
          .and_raise(RuntimeError, "command not found")
      end

      it "returns a failed result and persists the error" do
        result = service.call

        expect(result.success).to be false
        expect(result.exit_status).to be_nil

        job_run.reload

        expect(job_run.pre_hook_status).to eq("errored")
        expect(job_run.pre_hook_error_class).to eq("RuntimeError")
        expect(job_run.pre_hook_error_message).to eq("command not found")
      end
    end
  end
end
