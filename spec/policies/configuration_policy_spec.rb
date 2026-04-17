# frozen_string_literal: true

RSpec.describe ConfigurationPolicy do
  subject(:policy) { described_class.new(record, user:) }

  let(:record) { build(:configuration) }
  let(:user) { build(:user) }

  describe "#index?" do
    it { is_expected.not_to be_index }

    context "when the user is admin" do
      let(:user) { build(:user, :admin) }

      it { is_expected.to be_index }
    end
  end

  describe "#update?" do
    it { is_expected.not_to be_update }

    context "when the user is admin" do
      let(:user) { build(:user, :admin) }

      it { is_expected.to be_update }
    end
  end

  describe ".relation_scope" do
    subject(:scope) { policy.apply_scope(Configuration.all, type: :relation) }

    let(:policy) { described_class.new(nil, user:) }

    before { create(:configuration, key: "test.key") }

    it { is_expected.to be_empty }

    context "when the user is admin" do
      let(:user) { build(:user, :admin) }

      it { is_expected.not_to be_empty }
    end
  end
end
