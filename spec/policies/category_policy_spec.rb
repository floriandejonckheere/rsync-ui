# frozen_string_literal: true

RSpec.describe CategoryPolicy do
  subject(:policy) { described_class.new(record, user:) }

  let(:owner) { build(:user) }
  let(:other_user) { build(:user) }
  let(:admin) { build(:user, :admin) }
  let(:record) { build(:category, user: owner) }
  let(:user) { owner }

  describe "#update?" do
    it { is_expected.to be_update }

    context "when user is another user" do
      let(:user) { other_user }

      it { is_expected.not_to be_update }
    end

    context "when user is admin" do
      let(:user) { admin }

      it { is_expected.to be_update }
    end
  end

  describe "relation scope" do
    let(:owner) { create(:user) }
    let!(:own_category) { create(:category, user: owner) }
    let!(:other_category) { create(:category) }

    it "returns the categories of the user" do
      expect(policy.apply_scope(Category.all, type: :relation)).to contain_exactly(own_category)
    end

    context "when user is admin" do
      let(:user) { create(:user, :admin) }

      it "returns all categories" do
        expect(policy.apply_scope(Category.all, type: :relation)).to contain_exactly(own_category, other_category)
      end
    end
  end
end
