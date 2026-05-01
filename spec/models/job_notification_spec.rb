# frozen_string_literal: true

RSpec.describe JobNotification do
  subject(:job_notification) { create(:job_notification) }

  describe "associations" do
    it { is_expected.to belong_to(:job) }
    it { is_expected.to belong_to(:notification) }
  end

  describe "defaults" do
    it "defaults enabled to true" do
      expect(job_notification).to be_enabled
    end

    it "defaults on_start to false" do
      expect(job_notification).not_to be_on_start
    end

    it "defaults on_success to true" do
      expect(job_notification).to be_on_success
    end

    it "defaults on_failure to true" do
      expect(job_notification).to be_on_failure
    end
  end

  describe "uniqueness" do
    it "rejects duplicate (job, notification) pairs" do
      existing = create(:job_notification)
      duplicate = build(:job_notification, job: existing.job, notification: existing.notification)

      expect(duplicate).not_to be_valid
    end
  end
end
