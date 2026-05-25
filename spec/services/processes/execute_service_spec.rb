# frozen_string_literal: true

RSpec.describe Processes::ExecuteService do
  subject(:service) { described_class.new(command, job_run) }

  let(:user) { create(:user) }
  let(:job) { create(:job, user:) }
  let(:job_run) { create(:job_run, :pending, job:, user:) }
  let(:command) { "/bin/echo hello" }

  describe "#call" do
    it "yields the output IO and returns a successful exit status" do
      output = +""

      result = service.call { |io| output << io.read }

      expect(output).to eq("hello\n")
      expect(result.exit_status).to be_success
    end

    it "returns the non-zero exit status" do
      result = described_class.new("/bin/sh -c 'exit 7'", job_run).call { |io| io.read }

      expect(result.exit_status.exitstatus).to eq(7)
    end

    it "records the pid on the job_run while the process runs" do
      captured_pid = nil

      described_class.new("/bin/sh -c 'sleep 0.05'", job_run).call do |io|
        captured_pid = job_run.reload.pid
        io.read
      end

      expect(captured_pid).to be_a(Integer).and(be_positive)
    end

    it "clears the pid after the process exits" do
      service.call { |io| io.read }

      expect(job_run.reload.pid).to be_nil
    end

    it "spawns the process in its own process group" do
      allow(Open3).to receive(:popen2e).and_call_original

      service.call { |io| io.read }

      expect(Open3).to have_received(:popen2e).with(command, pgroup: true)
    end
  end
end
