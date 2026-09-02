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

  describe "#format_file_count" do
    it { expect(helper.format_file_count(0)).to eq "0" }
    it { expect(helper.format_file_count(999)).to eq "999" }
    it { expect(helper.format_file_count(1_000)).to eq "1k" }
    it { expect(helper.format_file_count(68_191)).to eq "68k" }
  end

  describe "#format_files_progress" do
    it { expect(helper.format_files_progress(nil, nil)).to be_nil }
    it { expect(helper.format_files_progress(126, nil)).to be_nil }
    it { expect(helper.format_files_progress(126, 68_191)).to eq "126/68k" }
  end
end
