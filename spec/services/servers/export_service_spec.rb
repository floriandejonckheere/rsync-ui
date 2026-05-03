# frozen_string_literal: true

RSpec.describe Servers::ExportService do
  subject(:service) { described_class.new(path: tmp_path) }

  let(:tmp_path) { Pathname.new(Dir.mktmpdir) }
  let(:user) { create(:user) }

  after { FileUtils.remove_entry(tmp_path) }

  describe "#call" do
    before { create(:server, :with_password, :online, name: "Production", host: "prod.example.com", user:) }

    it "creates a CSV file at the given path" do
      service.call

      expect(tmp_path.join("02_servers.csv")).to exist
    end

    it "writes server rows with the correct headers" do
      service.call

      rows = CSV.read(tmp_path.join("02_servers.csv"), headers: true)

      expect(rows.headers).to eq([
                                   "name", "description", "host", "port", "username", "password", "ssh_key", "probed_at", "last_seen_at", "error_class", "error_message", "user_email",
                                 ])
      expect(rows.first["name"]).to eq("Production")
      expect(rows.first["host"]).to eq("prod.example.com")
      expect(rows.first["user_email"]).to eq(user.email)
      expect(rows.first["last_seen_at"]).to be_present
    end
  end
end
