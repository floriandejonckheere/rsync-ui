# frozen_string_literal: true

RSpec.describe User do
  subject(:user) { build(:user) }

  describe "associations" do
    it { is_expected.to have_many(:servers).dependent(:destroy) }
    it { is_expected.to have_many(:repositories).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to validate_presence_of(:role) }
    it { is_expected.to validate_inclusion_of(:role).in_array ["user", "admin"] }

    it "downcases the email before saving" do
      user.email = user.email.upcase

      user.save!

      expect(user.email).to eq user.email.downcase
    end
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:role).with_values(user: "user", admin: "admin").backed_by_column_of_type(:string) }
  end

  describe "instance methods" do
    describe "#user?" do
      context "when role is user" do
        subject(:user) { build(:user) }

        it { is_expected.to be_user }
      end

      context "when role is admin" do
        subject(:admin) { build(:user, :admin) }

        it { is_expected.not_to be_user }
      end
    end

    describe "#admin?" do
      context "when role is admin" do
        subject(:admin) { build(:user, :admin) }

        it { is_expected.to be_admin }
      end

      context "when role is user" do
        subject(:user) { build(:user) }

        it { is_expected.not_to be_admin }
      end
    end

    describe "#full_name" do
      subject(:user) { build(:user, first_name: "John", last_name: "Doe") }

      it "returns the full name" do
        expect(user.full_name).to eq "John Doe"
      end
    end
  end
end
