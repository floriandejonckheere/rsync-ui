# frozen_string_literal: true

RSpec.describe Notifications::ImportService do
  subject(:service) { described_class.new(path: tmp_path) }

  let(:tmp_path) { Pathname.new(Dir.mktmpdir) }
  let(:user) { create(:user) }

  after { FileUtils.remove_entry(tmp_path) }

  describe "#call" do
    context "when the CSV file exists" do
      before do
        user

        tmp_path.join("06_notifications.csv").write(<<~CSV)
          name,description,url,enabled,user_email
          Slack,Slack webhook,json://hooks.slack.com/services/XXX,true,#{user.email}
          Email,Email webhook,https://hooks.example.com/email,false,#{user.email}
        CSV
      end

      it "creates notifications from the CSV" do
        expect { service.call }.to change(Notification, :count).by(2)
      end

      it "associates notifications with the correct user" do
        service.call

        notification = Notification.find_by!(name: "Slack")

        expect(notification.user).to eq(user)
      end

      it "sets notification attributes from the CSV" do
        service.call

        notification = Notification.find_by!(name: "Slack")

        expect(notification.description).to eq("Slack webhook")
        expect(notification.url).to eq("json://hooks.slack.com/services/XXX")
      end

      it "casts the enabled flag from the CSV" do
        service.call

        expect(Notification.find_by!(name: "Slack").enabled).to be(true)
        expect(Notification.find_by!(name: "Email").enabled).to be(false)
      end

      it "is idempotent" do
        expect { 2.times { service.call } }.to change(Notification, :count).by(2)
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
