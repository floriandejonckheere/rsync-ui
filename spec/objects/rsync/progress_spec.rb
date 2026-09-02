# frozen_string_literal: true

RSpec.describe Rsync::Progress do
  subject(:progress) { described_class.new(line, aggregate:) }

  let(:aggregate) { false }

  context "when the line does not match" do
    let(:line) { "some random line" }

    it { expect(progress.bytes).to be_nil }
    it { expect(progress.progress).to be_nil }
    it { expect(progress.speed).to be_nil }
    it { expect(progress.remaining_time).to be_nil }
    it { expect(progress.files_transferred).to be_nil }
    it { expect(progress.files_checked).to be_nil }
    it { expect(progress.files_total).to be_nil }
  end

  context "with a raw bytes progress line" do
    let(:line) { "  1,234,567  75%  10.00MB/s  0:00:10" }

    it { expect(progress.bytes).to eq 1_234_567 }
    it { expect(progress.progress).to eq 75 }
    it { expect(progress.speed).to eq 10_000_000 }
    it { expect(progress.remaining_time).to eq 10 }
    it { expect(progress).not_to be_remaining_time_approximate }
    it { expect(progress.files_transferred).to be_nil }
    it { expect(progress.files_checked).to be_nil }
    it { expect(progress.files_total).to be_nil }
  end

  context "with a human-readable progress line including file stats" do
    let(:line) { "105.45M 13% 602.83kB/s 0:02:50 (xfr#495, ir-chk=1020/3825)" }

    # rsync's own time field here (0:02:50) is elapsed time, not remaining time, so
    # remaining_time is derived from bytes/progress/speed instead: (105_450_000 / 13 *
    # 87) / 602_830 rounds to 1_171 seconds.
    it { expect(progress.bytes).to eq 105_450_000 }
    it { expect(progress.progress).to eq 13 }
    it { expect(progress.speed).to eq 602_830 }
    it { expect(progress.remaining_time).to eq 1_171 }
    it { expect(progress).to be_remaining_time_approximate }
    it { expect(progress.files_transferred).to eq 495 }
    it { expect(progress.files_checked).to eq 1_020 }
    it { expect(progress.files_total).to eq 3_825 }
  end

  context "with a progress line at 0%" do
    let(:line) { "297,199,869 0% 10.02MB/s 0:00:28 (xfr#299, to-chk=67858/68191)" }

    it { expect(progress.remaining_time).to be_nil }
    it { expect(progress).to be_remaining_time_approximate }
  end

  context "with an --info=progress2 intermediate tick (no xfr#/to-chk suffix yet)" do
    let(:line) { "  1,234,567  75%  10.00MB/s  0:00:10" }
    let(:aggregate) { true }

    # Even without the suffix, this is still an --info=progress2 line, so rsync's own
    # time field is not trusted here: it would disagree with the formula-derived value
    # used once the suffix appears, causing the UI to flicker between two ETAs for the
    # same aggregate transfer. remaining_time is computed instead, same as when the
    # suffix is present: (1_234_567 / 75 * 25) / 10_000_000 rounds to 0 seconds.
    it { expect(progress.remaining_time).to eq 0 }
    it { expect(progress).to be_remaining_time_approximate }
  end
end
