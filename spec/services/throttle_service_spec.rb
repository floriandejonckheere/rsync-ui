# frozen_string_literal: true

RSpec.describe ThrottleService do
  subject(:throttle) { described_class.new(interval: 1.second) }

  let(:calls) { [] }

  it "calls the block on the first call" do
    throttle.call { calls << :first }

    expect(calls).to eq [:first]
  end

  it "does not call the block again within the interval" do
    throttle.call { calls << :first }
    throttle.call { calls << :second }

    expect(calls).to eq [:first]
  end

  it "calls the block again once the interval has elapsed" do
    throttle.call { calls << :first }

    travel_to(1.second.from_now + 1.second) do
      throttle.call { calls << :second }
    end

    expect(calls).to eq [:first, :second]
  end
end
