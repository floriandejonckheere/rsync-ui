# frozen_string_literal: true

RSpec.describe Audits::PurgeJob do
  subject(:job) { described_class.new }

  describe "#perform" do
    it "calls Audits::PurgeService" do
      allow(Audits::PurgeService)
        .to receive(:call)

      job.perform

      expect(Audits::PurgeService)
        .to have_received(:call)
    end
  end
end
