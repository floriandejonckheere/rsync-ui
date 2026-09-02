# frozen_string_literal: true

RSpec.describe JobRunHelper do
  describe "#format_remaining_time" do
    it { expect(helper.format_remaining_time(nil)).to be_nil }
    it { expect(helper.format_remaining_time(0)).to eq "< 1 min" }
    it { expect(helper.format_remaining_time(59)).to eq "< 1 min" }
    it { expect(helper.format_remaining_time(3_599)).to eq "< 1 min" }
    it { expect(helper.format_remaining_time(3_600)).to eq "1:00" }
    it { expect(helper.format_remaining_time(19_450)).to eq "5:24" }
    it { expect(helper.format_remaining_time(3_600, approximate: true)).to eq "~1:00" }
  end
end
