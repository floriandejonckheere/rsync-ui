# frozen_string_literal: true

RSpec.describe JobNotifications::ExportService do
  subject(:service) { described_class.new(path: tmp_path) }

  let(:tmp_path) { Pathname.new(Dir.mktmpdir) }
  let(:user) { create(:user) }
  let(:job) { create(:job, user:, name: "System backup") }
  let(:notification) { create(:notification, user:, name: "Slack") }

  after { FileUtils.remove_entry(tmp_path) }

  describe "#call" do
    before do
      create(:job_notification, job:, notification:, enabled: true, on_start: true, on_success: false, on_failure: true)
    end

    it "writes a CSV file" do
      service.call

      expect(tmp_path.join("exports.csv")).to exist
    end

    it "writes the correct headers" do
      service.call

      rows = CSV.read(tmp_path.join("exports.csv"), headers: true)

      expect(rows.headers).to eq(["job_name", "notification_name", "user_email", "enabled", "on_start", "on_success", "on_failure"])
    end

    it "writes one row per job notification" do
      service.call

      rows = CSV.read(tmp_path.join("exports.csv"), headers: true)

      expect(rows.length).to eq(1)
    end

    it "writes job notification attributes to the CSV" do
      service.call

      row = CSV.read(tmp_path.join("exports.csv"), headers: true).first

      expect(row["job_name"]).to eq("System backup")
      expect(row["notification_name"]).to eq("Slack")
      expect(row["user_email"]).to eq(user.email)
      expect(row["enabled"]).to eq("true")
      expect(row["on_start"]).to eq("true")
      expect(row["on_success"]).to eq("false")
      expect(row["on_failure"]).to eq("true")
    end
  end
end
