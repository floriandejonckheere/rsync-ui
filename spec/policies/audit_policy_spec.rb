# frozen_string_literal: true

RSpec.describe AuditPolicy do
  subject(:policy) { described_class.new(record, user:) }

  let(:record) { build(:audit) }

  describe "#index?" do
    context "when user is admin" do
      let(:user) { build(:user, :admin) }

      it { is_expected.to be_index }
    end

    context "when user is not admin" do
      let(:user) { build(:user) }

      it { is_expected.not_to be_index }
    end
  end

  describe "#show?" do
    context "when user is admin" do
      let(:user) { build(:user, :admin) }

      it { is_expected.to be_show }
    end

    context "when user is not admin" do
      let(:user) { build(:user) }

      it { is_expected.not_to be_show }
    end
  end

  describe "scope" do
    subject(:scope) { described_class.new(Audit, user: create(:user, :admin)).apply_scope(Audit.all, type: :relation) }

    before do
      create(:audit)
      create(:audit)
    end

    it "returns all audits" do
      expect(scope.count).to eq(2)
    end
  end
end
