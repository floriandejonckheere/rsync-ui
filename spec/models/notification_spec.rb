# frozen_string_literal: true

RSpec.describe Notification do
  subject(:notification) { build(:notification) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:job_notifications).dependent(:restrict_with_error) }
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

  describe "#destroy" do
    subject(:notification) { create(:notification) }

    context "when the notification is not used by any job" do
      it "destroys the notification" do
        notification.destroy

        expect(notification).to be_destroyed
      end
    end

    context "when the notification is used by a job" do
      before { create(:job_notification, notification:) }

      it "does not destroy the notification" do
        notification.destroy

        expect(notification).not_to be_destroyed
      end

      it "adds an error on base" do
        notification.destroy

        expect(notification.errors[:base]).to be_present
      end
    end
  end
end
