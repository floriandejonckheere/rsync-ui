# frozen_string_literal: true

RSpec.describe Audits::PurgeService do
  subject(:service) { described_class.new }

  with_configuration "audits.retention" => 7

  let!(:old_audit) { create(:audit, started_at: 8.days.ago) }
  let!(:recent_audit) { create(:audit, started_at: 6.days.ago) }

  describe "#call" do
    it "removes audits older than the retention period" do
      service.call

      expect(Audit.exists?(old_audit.id)).to be false
      expect(Audit.exists?(recent_audit.id)).to be true
    end
  end
end
