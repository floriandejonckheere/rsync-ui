# frozen_string_literal: true

RSpec.describe Rsync::Progress do
  subject(:progress) { described_class.new(line) }

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
    it { expect(progress.files_transferred).to be_nil }
    it { expect(progress.files_checked).to be_nil }
    it { expect(progress.files_total).to be_nil }
  end

  context "with a human-readable progress line including file stats" do
    let(:line) { "105.45M 13% 602.83kB/s 0:02:50 (xfr#495, ir-chk=1020/3825)" }

    it { expect(progress.bytes).to eq 105_450_000 }
    it { expect(progress.progress).to eq 13 }
    it { expect(progress.speed).to eq 602_830 }
    it { expect(progress.remaining_time).to eq 170 }
    it { expect(progress.files_transferred).to eq 495 }
    it { expect(progress.files_checked).to eq 1_020 }
    it { expect(progress.files_total).to eq 3_825 }
  end
end
