# frozen_string_literal: true

RSpec.describe JobRuns::OutputBuffer do
  let(:job_run) { create(:job_run, :running) }

  describe "#<<" do
    subject(:output_buffer) { described_class.new(job_run) }

    it "does not flush to the cache before the flush threshold is reached" do
      output_buffer << "file.txt\n"

      expect(described_class.read(job_run)).to eq ""
    end

    context "when the buffered content reaches the flush size threshold" do
      it "flushes to the cache" do
        output_buffer << ("a" * (described_class::FLUSH_BYTES + 1))

        expect(described_class.read(job_run)).to eq("a" * (described_class::FLUSH_BYTES + 1))
      end
    end

    context "when the flush interval has elapsed" do
      it "flushes to the cache" do
        output_buffer << "file.txt\n"

        travel_to(described_class::FLUSH_INTERVAL.from_now + 1.second) do
          output_buffer << "other.txt\n"
        end

        expect(described_class.read(job_run)).to eq "file.txt\nother.txt\n"
      end
    end
  end

  describe "#flush" do
    subject(:output_buffer) { described_class.new(job_run) }

    it "appends the buffered content to any content already cached" do
      described_class.new(job_run).tap do |first|
        first << "file.txt\n"
        first.flush
      end

      output_buffer << "other.txt\n"
      output_buffer.flush

      expect(described_class.read(job_run)).to eq "file.txt\nother.txt\n"
    end

    it "does nothing when nothing has been buffered" do
      output_buffer.flush

      expect(described_class.read(job_run)).to eq ""
    end
  end

  describe ".read" do
    context "when nothing has been buffered" do
      it "returns an empty string" do
        expect(described_class.read(job_run)).to eq ""
      end
    end

    context "when content has been buffered" do
      before { Rails.cache.write(described_class.cache_key(job_run), "file.txt\n") }

      it "returns the buffered content" do
        expect(described_class.read(job_run)).to eq "file.txt\n"
      end
    end
  end

  describe ".clear" do
    before { Rails.cache.write(described_class.cache_key(job_run), "file.txt\n") }

    it "removes the buffered content" do
      described_class.clear(job_run)

      expect(described_class.read(job_run)).to eq ""
    end

    it "does not return false" do
      expect(described_class.clear(job_run)).not_to be false
    end

    context "when nothing has been buffered" do
      before { Rails.cache.delete(described_class.cache_key(job_run)) }

      it "does not return false" do
        expect(described_class.clear(job_run)).not_to be false
      end
    end
  end
end
