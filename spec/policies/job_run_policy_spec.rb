# frozen_string_literal: true

RSpec.describe JobRunPolicy do
  subject(:policy) { described_class.new(record, user:) }

  let(:owner) { build(:user) }
  let(:other_user) { build(:user) }
  let(:admin) { build(:user, :admin) }
  let(:record) { build(:job_run, user: owner) }
  let(:user) { owner }

  describe "#index?" do
    it { is_expected.to be_index }
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

  describe "#cancel?" do
    it { is_expected.to be_cancel }

    context "when user is another user" do
      let(:user) { other_user }

      it { is_expected.not_to be_cancel }
    end

    context "when user is admin" do
      let(:user) { admin }

      it { is_expected.to be_cancel }
    end
  end

  describe "#create?" do
    let(:record) { build(:job_run, job: build(:job, user: owner)) }

    it { is_expected.to be_create }

    context "when user is another user" do
      let(:user) { other_user }

      it { is_expected.not_to be_create }
    end

    context "when user is admin" do
      let(:user) { admin }

      it { is_expected.to be_create }
    end
  end

  describe ".relation_scope" do
    subject(:scope) { policy.apply_scope(JobRun.all, type: :relation) }

    let(:policy) { described_class.new(nil, user: owner) }
    let(:owner) { create(:user) }
    let(:other_user) { create(:user) }

    before do
      create(:job_run, user: owner)
      create(:job_run, user: other_user)
    end

    it "returns only the user's own job runs" do
      expect(scope.count).to eq(1)
    end

    context "when user is admin" do
      let(:policy) { described_class.new(nil, user: admin) }
      let(:admin) { create(:user, :admin) }

      it "returns all job runs" do
        expect(scope.count).to eq(2)
      end
    end
  end
end
