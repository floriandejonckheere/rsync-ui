# frozen_string_literal: true

RSpec.describe Notification do
  subject(:notification) { build(:notification) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:job_notifications).dependent(:destroy) }
    it { is_expected.to have_many(:jobs).through(:job_notifications) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:url) }

    context "when url has no scheme" do
      subject(:notification) { build(:notification, url: "no-scheme") }

      it { is_expected.not_to be_valid }
    end

    context "when url is malformed" do
      subject(:notification) { build(:notification, url: "ht!tp://[bad") }

      it { is_expected.not_to be_valid }
    end
  end

  describe "encryption" do
    it { is_expected.to encrypt :url }
  end
end
