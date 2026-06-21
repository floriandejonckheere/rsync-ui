# frozen_string_literal: true

RSpec.describe Rsync::ExecuteService do
  subject(:service) { described_class.new(job_run) }

  let(:user) { create(:user) }
  let(:job) { create(:job, user:) }
  let(:job_run) { create(:job_run, :pending, job:, user:) }

  let(:output) { instance_double(IO) }
  let(:exit_status) { instance_double(Process::Status, success?: true, signaled?: false, exitstatus: 0) }
  let(:wait_thr) { instance_double(Process::Waiter, pid: 12_345, value: exit_status) }

  before do
    allow(Open3)
      .to receive(:popen2e)
        .with(job_run.command, pgroup: true) { |_command, pgroup:, &block| block.call(nil, output, wait_thr) } # rubocop:disable Lint/UnusedBlockArgument

    calls = 0
    allow(output).to receive(:readpartial) do
      calls += 1
      raise EOFError if calls > 1

      "output line\n"
    end
  end

  describe "#call" do
    it "returns a result with exit status" do
      result = service.call

      expect(result.exit_status).to eq exit_status
    end

    it "yields each output line" do
      lines = []
      service.call { |line| lines << line }

      expect(lines).to eq ["output line\n"]
    end

    it "flushes a trailing partial line without a newline" do
      calls = 0
      allow(output).to receive(:readpartial) do
        calls += 1
        raise EOFError if calls > 1

        "no newline at end"
      end

      lines = []
      service.call { |line| lines << line }

      expect(lines).to eq ["no newline at end"]
    end

    describe "timeouts" do
      before do
        allow(Timeout)
          .to receive(:timeout)
          .with(a_kind_of(Integer))
          .and_raise Timeout::Error

        allow(Timeout)
          .to receive(:timeout)
          .with(0)
          .and_call_original
      end

      context "when job timeouts are disabled" do
        with_configuration "jobs.timeout" => 0

        it "returns a successful result" do
          result = service.call

          expect(result.success).to be true
          expect(result.exit_status).to be_zero

          job_run.reload

          expect(job_run).to be_completed
          expect(job_run.error_class).to be_nil
          expect(job_run.error_message).to be_nil
        end
      end

      context "when timeouts are enabled" do
        with_configuration "jobs.timeout" => 1

        it "returns a failed result" do
          result = service.call

          expect(result.success).to be true
          expect(result.exit_status).to be_zero

          job_run.reload

          expect(job_run).to be_errored
          expect(job_run.error_class).to eq("Timeout::Error")
          expect(job_run.error_message).to eq("execution expired after 1 minutes")
        end
      end
    end
  end
end
