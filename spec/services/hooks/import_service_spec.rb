# frozen_string_literal: true

RSpec.describe Hooks::ImportService do
  subject(:service) { described_class.new(path: tmp_path) }

  let(:tmp_path) { Pathname.new(Dir.mktmpdir) }
  let(:user) { create(:user) }
  let(:job) { create(:job, user:) }

  after { FileUtils.remove_entry(tmp_path) }

  describe "#call" do
    context "when the CSV file exists" do
      before do
        user
        job

        tmp_path.join("08_hooks.csv").write(<<~CSV)
          hook_type,command,arguments,enabled,job_name,user_email
          pre,/usr/local/bin/stop.sh,,true,#{job.name},#{user.email}
        CSV
      end

      it "creates hooks from the CSV" do
        expect { service.call }.to change(Hook, :count).by(1)
      end

      it "associates the hook with the correct job and sets attributes" do
        service.call

        hook = Hook.sole

        expect(hook.job).to eq(job)
        expect(hook.hook_type).to eq("pre")
        expect(hook.command).to eq("/usr/local/bin/stop.sh")
        expect(hook.enabled).to be(true)
      end

      it "is idempotent" do
        expect { 2.times { service.call } }.to change(Hook, :count).by(1)
      end
    end

    context "when the CSV file does not exist" do
      it "raises an error" do
        expect { service.call }.to raise_error(ArgumentError)
      end
    end
  end
end
