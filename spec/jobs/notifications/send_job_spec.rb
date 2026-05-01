# frozen_string_literal: true

RSpec.describe Notifications::SendJob do
  let(:job_record) { create(:job) }
  let(:notification) { create(:notification, user: job_record.user) }
  let(:job_run) { create(:job_run, job: job_record, user: job_record.user) }
  let!(:job_notification) { create(:job_notification, job: job_record, notification:, on_start: true) }

  before do
    allow(Notifications::SendService)
      .to receive(:call)
      .and_return(success: true, output: "")
  end

  describe "#perform" do
    it "calls SendService when feature enabled, jn enabled, notification enabled, and event flag true" do
      described_class.new.perform(job_notification.id, job_run.id, "start")

      expect(Notifications::SendService).to have_received(:call).with(notification, job_run, "start")
    end

    it "no-ops when feature disabled" do
      Configuration.set("notifications", false)

      described_class.new.perform(job_notification.id, job_run.id, "start")

      expect(Notifications::SendService).not_to have_received(:call)
    end

    it "no-ops when join row disabled" do
      job_notification.update!(enabled: false)

      described_class.new.perform(job_notification.id, job_run.id, "start")

      expect(Notifications::SendService).not_to have_received(:call)
    end

    it "no-ops when notification disabled" do
      notification.update!(enabled: false)

      described_class.new.perform(job_notification.id, job_run.id, "start")

      expect(Notifications::SendService).not_to have_received(:call)
    end

    it "no-ops when on_start is false" do
      job_notification.update!(on_start: false)

      described_class.new.perform(job_notification.id, job_run.id, "start")

      expect(Notifications::SendService).not_to have_received(:call)
    end

    it "no-ops when on_success is false for success event" do
      job_notification.update!(on_success: false)

      described_class.new.perform(job_notification.id, job_run.id, "success")

      expect(Notifications::SendService).not_to have_received(:call)
    end
  end
end
