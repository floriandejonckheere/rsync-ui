# frozen_string_literal: true

RSpec.describe Processes::ExecuteService do
  subject(:service) { described_class.new(command, job_run, heartbeat_interval:) }

  let(:user) { create(:user) }
  let(:job) { create(:job, user:) }
  let(:job_run) { create(:job_run, :pending, job:, user:) }
  let(:command) { "echo hello" }
  let(:heartbeat_interval) { nil }

  let(:output) { instance_double(IO) }
  let(:exit_status) { instance_double(Process::Status, success?: true, signaled?: false, exitstatus: 0) }
  let(:wait_thr) { instance_double(Process::Waiter, pid: 12_345, value: exit_status) }

  before do
    stub_const("Processes::ExecuteService::CANCEL_MONITOR_INTERVAL", 0.05)

    allow(Open3)
      .to receive(:popen2e)
        .with(command, pgroup: true) { |_command, pgroup:, &block| block.call(nil, output, wait_thr) } # rubocop:disable Lint/UnusedBlockArgument

    allow(output)
      .to receive(:read)
      .and_return("")
  end

  describe "#call" do
    it "saves the pid and returns a result with exit status" do
      result = service.call { |_output| nil }

      expect(job_run.reload.pid).to eq 12_345
      expect(result.exit_status).to eq exit_status
      expect(result.canceled).to be false
    end

    context "when heartbeat_interval is set" do
      let(:heartbeat_interval) { 30 }

      it "writes a heartbeat to job_run while running" do
        service.call { |_output| nil }

        expect(job_run.reload.last_heartbeat_at).to be_present
      end
    end

    context "when heartbeat_interval is nil" do
      it "does not write a heartbeat" do
        service.call { |_output| nil }

        expect(job_run.reload.last_heartbeat_at).to be_nil
      end
    end

    context "when cancellation is requested while the command is running" do
      let(:wait_thr) { instance_double(Process::Waiter, pid: 43_210, value: instance_double(Process::Status, success?: false, signaled?: false, exitstatus: 1)) }

      before do
        allow(Open3).to receive(:popen2e) do |_command, pgroup:, &block|
          raise "expected process group" unless pgroup

          block.call(nil, output, wait_thr)
        end

        allow(Process).to receive(:kill)

        allow(output).to receive(:read) do
          JobRun
            .last
            .update!(cancel_requested_at: Time.zone.now)

          ""
        end
      end

      it "signals the process group" do
        service.call(&:read)

        expect(Process)
          .to have_received(:kill)
          .with("TERM", -43_210)
      end

      it "returns canceled: true" do
        result = service.call(&:read)

        expect(result.canceled).to be true
      end

      context "when the process has already exited" do
        before do
          allow(Process)
            .to receive(:kill)
            .and_raise(Errno::ESRCH)
        end

        it "does not raise" do
          expect { service.call(&:read) }.not_to raise_error
        end
      end
    end

    context "when cancellation is requested before the command produces output" do
      let(:wait_thr) { instance_double(Process::Waiter, pid: 43_210, value: instance_double(Process::Status, success?: false, signaled?: false, exitstatus: 1)) }

      before do
        job_run.update!(cancel_requested_at: Time.zone.now)

        killed = false

        allow(Process)
          .to receive(:kill) { killed = true }

        allow(output).to receive(:read) do
          sleep 0.01 until killed

          ""
        end
      end

      it "signals the process group via the monitor thread" do
        service.call { |_output| nil }

        expect(Process)
          .to have_received(:kill)
          .with("TERM", -43_210)
      end

      it "returns canceled: true" do
        result = service.call { |_output| nil }

        expect(result.canceled).to be true
      end
    end
  end
end
