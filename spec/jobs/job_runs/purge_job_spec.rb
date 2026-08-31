# frozen_string_literal: true

RSpec.describe JobRuns::PurgeJob do
  subject(:job) { described_class.new }

  describe "#perform" do
    it "calls JobRuns::PurgeService" do
      allow(JobRuns::PurgeService)
        .to receive(:call)

      job.perform

      expect(JobRuns::PurgeService)
        .to have_received(:call)
    end
  end
end
