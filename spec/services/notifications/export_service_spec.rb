# frozen_string_literal: true

RSpec.describe Notifications::ExportService do
  subject(:service) { described_class.new(path: tmp_path) }

  let(:tmp_path) { Pathname.new(Dir.mktmpdir) }
  let(:user) { create(:user) }

  after { FileUtils.remove_entry(tmp_path) }

  describe "#call" do
    before do
      create(:notification, user:, name: "Slack", description: "Slack webhook", url: "json://hooks.slack.com/services/XXX", enabled: true)
      create(:notification, user:, name: "Email", description: nil, url: "https://hooks.example.com/email", enabled: false)
    end

    it "writes a CSV file" do
      service.call

      expect(tmp_path.join("exports.csv")).to exist
    end

    it "writes the correct headers" do
      service.call

      rows = CSV.read(tmp_path.join("exports.csv"), headers: true)

      expect(rows.headers).to eq(["name", "description", "url", "enabled", "user_email"])
    end

    it "writes one row per notification" do
      service.call

      rows = CSV.read(tmp_path.join("exports.csv"), headers: true)

      expect(rows.length).to eq(2)
    end

    it "writes notification attributes to the CSV" do
      service.call

      row = CSV.read(tmp_path.join("exports.csv"), headers: true).find { |r| r["name"] == "Slack" }

      expect(row["description"]).to eq("Slack webhook")
      expect(row["url"]).to eq("json://hooks.slack.com/services/XXX")
      expect(row["enabled"]).to eq("true")
      expect(row["user_email"]).to eq(user.email)
    end
  end
end
