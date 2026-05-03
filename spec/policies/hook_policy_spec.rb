# frozen_string_literal: true

RSpec.describe HookPolicy do
  subject(:policy) { described_class.new(record, user:) }

  let(:owner) { build(:user) }
  let(:other_user) { build(:user) }
  let(:admin) { build(:user, :admin) }
  let(:job) { build(:job, user: owner) }
  let(:record) { build(:hook, job:) }
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
end
