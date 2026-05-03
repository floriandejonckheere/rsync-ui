# frozen_string_literal: true

RSpec.describe JobNotifications::ImportService do
  subject(:service) { described_class.new(path: tmp_path) }

  let(:tmp_path) { Pathname.new(Dir.mktmpdir) }
  let(:user) { create(:user) }
  let(:job) { create(:job, user:, name: "System backup") }
  let(:notification) { create(:notification, user:, name: "Slack") }

  after { FileUtils.remove_entry(tmp_path) }

  describe "#call" do
    context "when the CSV file exists" do
      before do
        job
        notification

        tmp_path.join("07_job_notifications.csv").write(<<~CSV)
          job_name,notification_name,user_email,enabled,on_start,on_success,on_failure
          System backup,Slack,#{user.email},true,true,false,true
        CSV
      end

      it "creates job notifications from the CSV" do
        expect { service.call }.to change(JobNotification, :count).by(1)
      end

      it "associates the job notification with the correct job and notification" do
        service.call

        job_notification = JobNotification.last

        expect(job_notification.job).to eq(job)
        expect(job_notification.notification).to eq(notification)
      end

      it "casts the trigger flags from the CSV" do
        service.call

        job_notification = JobNotification.last

        expect(job_notification.enabled).to be(true)
        expect(job_notification.on_start).to be(true)
        expect(job_notification.on_success).to be(false)
        expect(job_notification.on_failure).to be(true)
      end

      it "is idempotent" do
        expect { 2.times { service.call } }.to change(JobNotification, :count).by(1)
      end
    end

    context "when the CSV file does not exist" do
      it "raises an error" do
        expect { service.call }
          .to raise_error ArgumentError
      end
    end
  end
end
