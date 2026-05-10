# frozen_string_literal: true

RSpec.describe Rsync::ExecuteService do
  subject(:service) { described_class.new(command, job_run) }

  let(:user) { create(:user) }
  let(:job) { create(:job, user:) }
  let(:job_run) { create(:job_run, :pending, job:, user:) }
  let(:command) { "rsync --recursive" }

  let(:output) { instance_double(IO) }
  let(:exit_status) { instance_double(Process::Status, success?: true, signaled?: false, exitstatus: 0) }
  let(:wait_thr) { instance_double(Process::Waiter, pid: 12_345, value: exit_status) }

  before do
    allow(Open3)
      .to receive(:popen2e)
        .with(command, pgroup: true) { |_command, pgroup:, &block| block.call(nil, output, wait_thr) } # rubocop:disable Lint/UnusedBlockArgument

    calls = 0
    allow(output).to receive(:readpartial) do
      calls += 1
      raise EOFError if calls > 1

      "output line\n"
    end
  end

  describe "#call" do
    it "saves the pid and returns a result with exit status" do
      result = service.call

      expect(job_run.reload.pid).to eq 12_345
      expect(result.exit_status).to eq exit_status
      expect(result.canceled).to be false
    end

    it "yields each output line" do
      lines = []
      service.call { |line| lines << line }

      expect(lines).to eq ["output line\n"]
    end

    it "writes a heartbeat to job_run while running" do
      service.call

      expect(job_run.reload.last_heartbeat_at).to be_present
    end

    context "when cancellation is requested while the command is running" do
      let(:wait_thr) { instance_double(Process::Waiter, pid: 43_210, value: instance_double(Process::Status, success?: false, signaled?: false, exitstatus: 1)) }

      before do
        allow(Open3).to receive(:popen2e) do |_command, pgroup:, &block|
          raise "expected process group" unless pgroup

          block.call(nil, output, wait_thr)
        end

        calls = 0
        allow(output).to receive(:readpartial) do
          calls += 1
          raise EOFError if calls > 1

          JobRun.last.update!(cancel_requested_at: Time.zone.now)
          "partial log line\n"
        end

        allow(Process).to receive(:kill)
      end

      it "signals the process group" do
        service.call

        expect(Process).to have_received(:kill).with("TERM", -43_210)
      end

      it "returns canceled: true" do
        result = service.call

        expect(result.canceled).to be true
      end

      context "when the process has already exited" do
        before { allow(Process).to receive(:kill).and_raise(Errno::ESRCH) }

        it "does not raise" do
          expect { service.call }.not_to raise_error
        end
      end
    end

    context "when cancellation is requested while the command produces no output" do
      let(:wait_thr) { instance_double(Process::Waiter, pid: 43_210, value: instance_double(Process::Status, success?: false, signaled?: false, exitstatus: 1)) }

      before do
        job_run.update!(cancel_requested_at: Time.zone.now)

        killed = false
        allow(Process).to receive(:kill) { killed = true }

        allow(output).to receive(:readpartial) do
          sleep 0.01 until killed
          raise EOFError
        end
      end

      it "signals the process group via the monitor thread" do
        service.call

        expect(Process).to have_received(:kill).with("TERM", -43_210)
      end

      it "returns canceled: true" do
        result = service.call

        expect(result.canceled).to be true
      end
    end
  end
end
