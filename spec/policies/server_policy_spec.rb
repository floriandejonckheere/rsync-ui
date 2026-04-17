# frozen_string_literal: true

RSpec.describe ServerPolicy do
  subject(:policy) { described_class.new(record, user:) }

  let(:owner) { build(:user) }
  let(:other_user) { build(:user) }
  let(:admin) { build(:user, :admin) }
  let(:record) { build(:server, user: owner) }
  let(:user) { owner }

  describe "#index?" do
    it { is_expected.to be_index }
  end

  describe "#create?" do
    it { is_expected.to be_create }
  end

  describe "#edit?" do
    it { is_expected.to be_edit }

    context "when user is another user" do
      let(:user) { other_user }

      it { is_expected.not_to be_edit }
    end

    context "when user is admin" do
      let(:user) { admin }

      it { is_expected.to be_edit }
    end
  end

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

  describe "#destroy?" do
    it { is_expected.to be_destroy }

    context "when user is another user" do
      let(:user) { other_user }

      it { is_expected.not_to be_destroy }
    end

    context "when user is admin" do
      let(:user) { admin }

      it { is_expected.to be_destroy }
    end
  end

  describe ".relation_scope" do
    subject(:scope) { policy.apply_scope(Server.all, type: :relation) }

    let(:policy) { described_class.new(nil, user: owner) }
    let(:owner) { create(:user) }
    let(:other_user) { create(:user) }

    before do
      create(:server, user: owner)
      create(:server, user: other_user)
    end

    it "returns only the user's own servers" do
      expect(scope.count).to eq(1)
    end

    context "when user is admin" do
      let(:policy) { described_class.new(nil, user: admin) }
      let(:admin) { create(:user, :admin) }

      it "returns all servers" do
        expect(scope.count).to eq(2)
      end
    end
  end
end
