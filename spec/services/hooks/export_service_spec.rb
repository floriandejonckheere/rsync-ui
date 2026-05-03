# frozen_string_literal: true

RSpec.describe Hooks::ExportService do
  subject(:service) { described_class.new(path: tmp_path) }

  let(:tmp_path) { Pathname.new(Dir.mktmpdir) }
  let(:user) { create(:user) }
  let(:job) { create(:job, user:) }

  after { FileUtils.remove_entry(tmp_path) }

  describe "#call" do
    before { create(:hook, :pre, job:, command: "/usr/bin/backup.sh", enabled: true) }

    it "creates a CSV file at the given path" do
      service.call

      expect(tmp_path.join("08_hooks.csv")).to exist
    end

    it "writes hook rows with the correct headers" do
      service.call

      rows = CSV.read(tmp_path.join("08_hooks.csv"), headers: true)

      expect(rows.headers).to eq(["hook_type", "command", "arguments", "enabled", "job_name", "user_email"])
      expect(rows.first["command"]).to eq("/usr/bin/backup.sh")
      expect(rows.first["job_name"]).to eq(job.name)
      expect(rows.first["user_email"]).to eq(user.email)
    end
  end
end
