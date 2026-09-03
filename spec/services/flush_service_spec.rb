# frozen_string_literal: true

RSpec.describe FlushService do
  subject(:flusher) { described_class.new(interval: 1.second) }

  let(:calls) { [] }
  let(:block) { ->(entries) { calls << entries } }

  describe "#call" do
    it "does not yield when nothing has been buffered" do
      flusher.call(&block)

      expect(calls).to be_empty
    end

    it "yields the entry on the first call" do
      flusher.call("first", &block)

      expect(calls).to eq [["first"]]
    end

    it "clears the buffer after yielding" do
      flusher.call("first", &block)
      flusher.call(&block)

      expect(calls).to eq [["first"]]
    end

    it "does not yield again within the interval" do
      flusher.call("first", &block)
      flusher.call("second", &block)

      expect(calls).to eq [["first"]]
    end

    it "batches entries added since the last call once the interval has elapsed" do
      flusher.call("first", &block)
      flusher.call("second", &block)

      travel_to(1.second.from_now + 1.second) do
        flusher.call("third", &block)
      end

      expect(calls).to eq [["first"], ["second", "third"]]
    end

    context "when forced" do
      it "yields buffered entries regardless of the interval" do
        flusher.call("first", &block)
        flusher.call("second", force: true, &block)

        expect(calls).to eq [["first"], ["second"]]
      end

      it "still does not yield when nothing has been buffered" do
        flusher.call(force: true, &block)

        expect(calls).to be_empty
      end
    end
  end
end
