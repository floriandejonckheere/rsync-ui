# frozen_string_literal: true

RSpec.describe Rsync::ExecuteService do
  subject(:service) { described_class.new(job_run) }

  let(:user) { create(:user) }
  let(:job) { create(:job, user:) }
  let(:job_run) { create(:job_run, :pending, job:, user:, command: "true") }

  describe "#call" do
    it "returns a successful result" do
      result = service.call

      expect(result.success).to be true
      expect(result.exit_status).to be_zero
    end

    context "when the command exits with a non-zero status" do
      let(:job_run) { create(:job_run, :pending, job:, user:, command: "false") }

      it "returns an unsuccessful result" do
        result = service.call

        expect(result.success).to be false
        expect(result.exit_status).to eq 1
      end
    end

    context "when output contains full lines" do
      let(:job_run) { create(:job_run, :pending, job:, user:, command: "echo 'output line'") }

      it "yields each output line" do
        lines = []

        service.call { |line| lines << line }

        expect(lines).to eq ["output line\n"]
      end
    end

    context "when output contains non-ASCII characters" do
      let(:filename) { "Classics/Albert Camus/L'étranger - Albert Camus (2011).epub" }
      let(:job_run) { create(:job_run, :pending, job:, user:, command: "printf '%s\\n' #{Shellwords.escape(filename)}") }

      it "yields lines decoded as UTF-8 without raising" do
        lines = []

        expect { service.call { |line| lines << line } }.not_to raise_error

        expect(lines).to eq ["#{filename}\n"]
        expect(lines.first.encoding).to eq Encoding::UTF_8
      end
    end

    context "when a multi-byte character straddles a read chunk boundary" do
      let(:padding) { "a" * 4095 }
      let(:filename) { "#{padding}é rest" }
      let(:job_run) { create(:job_run, :pending, job:, user:, command: "printf '%s\\n' #{Shellwords.escape(filename)}") }

      it "reassembles the character correctly without raising" do
        lines = []

        expect { service.call { |line| lines << line } }.not_to raise_error

        expect(lines).to eq ["#{filename}\n"]
        expect(lines.first.encoding).to eq Encoding::UTF_8
      end
    end

    context "when output has no trailing newline" do
      let(:job_run) { create(:job_run, :pending, job:, user:, command: "printf 'no newline at end'") }

      it "flushes a trailing partial line without a newline" do
        lines = []

        service.call { |line| lines << line }

        expect(lines).to eq ["no newline at end"]
      end
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
        end
      end

      context "when timeouts are enabled" do
        with_configuration "jobs.timeout" => 1

        it "raises an error" do
          expect { service.call }
            .to raise_error Timeout::Error
        end
      end
    end
  end
end
