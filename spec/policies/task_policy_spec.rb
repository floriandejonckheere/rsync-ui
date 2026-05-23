# frozen_string_literal: true

RSpec.describe TaskPolicy do
  subject(:policy) { described_class.new(record, user:) }

  let(:record) { build(:task) }
  let(:user) { build(:user) }

  describe "#run?" do
    it { is_expected.not_to be_run }

    context "when the user is admin" do
      let(:user) { build(:user, :admin) }

      it { is_expected.to be_run }
    end
  end
end
