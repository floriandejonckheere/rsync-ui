# frozen_string_literal: true

RSpec.describe JobRunHelper do
  describe "#format_remaining_time" do
    it { expect(helper.format_remaining_time(nil)).to be_nil }
    it { expect(helper.format_remaining_time(0)).to eq "< 1 min" }
    it { expect(helper.format_remaining_time(59)).to eq "< 1 min" }
    it { expect(helper.format_remaining_time(60)).to eq "1m" }
    it { expect(helper.format_remaining_time(3_599)).to eq "59m" }
    it { expect(helper.format_remaining_time(3_600)).to eq "1h 0m" }
    it { expect(helper.format_remaining_time(19_450)).to eq "5h 24m" }
    it { expect(helper.format_remaining_time(3_600, approximate: true)).to eq "~1h 0m" }
    it { expect(helper.format_remaining_time(60, approximate: true)).to eq "~1m" }
  end
end
