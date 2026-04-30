# frozen_string_literal: true

RSpec.describe UserPolicy do
  subject(:policy) { described_class.new(record, user:) }

  let(:record) { build(:user) }
  let(:user) { build(:user) }

  describe "#create?" do
    it { is_expected.to be_create }
  end

  describe "#update?" do
    it { is_expected.not_to be_update }

    context "when the record is the current user" do
      let(:record) { user }

      it { is_expected.to be_update }
    end

    context "when the user is admin" do
      let(:user) { create(:user, :admin) }

      it { is_expected.to be_update }
    end
  end

  describe "#destroy?" do
    it { is_expected.not_to be_destroy }

    context "when the record is the current user" do
      let(:record) { user }

      it { is_expected.not_to be_destroy }
    end

    context "when the user is admin" do
      let(:user) { create(:user, :admin) }

      it { is_expected.not_to be_destroy }
    end
  end
end
