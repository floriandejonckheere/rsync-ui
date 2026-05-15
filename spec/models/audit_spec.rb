# frozen_string_literal: true

RSpec.describe Audit do
  subject(:audit) { build(:audit) }

  describe "associations" do
    it { is_expected.to belong_to(:server) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:command) }
    it { is_expected.to validate_presence_of(:started_at) }
  end

  describe "scopes" do
    describe ".by_server" do
      it "filters by server_id" do
        server = create(:server)
        match = create(:audit, server:)
        no_match = create(:audit)

        expect(described_class.by_server(server.id)).to include(match)
        expect(described_class.by_server(server.id)).not_to include(no_match)
      end

      it "returns all when blank" do
        create(:audit)
        expect(described_class.by_server(nil).count).to eq(described_class.count)
      end
    end

    describe ".completed" do
      it "filters completed audits (exit_status 0)" do
        match = create(:audit, exit_status: 0)
        no_match = create(:audit, exit_status: 1)

        expect(described_class.completed).to include(match)
        expect(described_class.completed).not_to include(no_match)
      end
    end

    describe ".failed" do
      it "filters failed audits (exit_status non-zero)" do
        match = create(:audit, exit_status: 1)
        no_match = create(:audit, exit_status: 0)
        nil_audit = create(:audit, exit_status: nil)

        expect(described_class.failed).to include(match)
        expect(described_class.failed).not_to include(no_match)
        expect(described_class.failed).not_to include(nil_audit)
      end
    end

    describe ".started_from" do
      it "filters audits started on or after the given time" do
        match = create(:audit, started_at: 1.hour.ago)
        no_match = create(:audit, started_at: 3.hours.ago)

        expect(described_class.started_from(2.hours.ago)).to include(match)
        expect(described_class.started_from(2.hours.ago)).not_to include(no_match)
      end
    end

    describe ".started_to" do
      it "filters audits started on or before the given time" do
        match = create(:audit, started_at: 3.hours.ago)
        no_match = create(:audit, started_at: 1.hour.ago)

        expect(described_class.started_to(2.hours.ago)).to include(match)
        expect(described_class.started_to(2.hours.ago)).not_to include(no_match)
      end
    end
  end
end
