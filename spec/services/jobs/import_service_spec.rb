# frozen_string_literal: true

RSpec.describe Jobs::ImportService do
  subject(:service) { described_class.new(path: tmp_path) }

  let(:tmp_path) { Pathname.new(Dir.mktmpdir) }
  let(:user) { create(:user) }
  let(:source_repository) { create(:repository, user:, name: "Source Repository") }
  let(:destination_repository) { create(:repository, user:, name: "Destination Repository") }

  after { FileUtils.remove_entry(tmp_path) }

  describe "#call" do
    context "when the CSV file exists" do
      before do
        source_repository
        destination_repository

        tmp_path.join("04_jobs.csv").write(<<~CSV)
          name,description,source_repository_name,destination_repository_name,schedule,enabled,user_email
          Daily backup,Nightly synchronization,Source Repository,Destination Repository,0 2 * * *,true,#{user.email}
          Ad hoc sync,Manual fallback,Destination Repository,Source Repository,,false,#{user.email}
        CSV
      end

      it "creates jobs from the CSV" do
        expect { service.call }.to change(Job, :count).by(2)
      end

      it "associates jobs with the correct user" do
        service.call

        job = Job.find_by!(name: "Daily backup")

        expect(job.user).to eq(user)
      end

      it "resolves repository associations from names" do
        service.call

        job = Job.find_by!(name: "Daily backup")

        expect(job.source_repository).to eq(source_repository)
        expect(job.destination_repository).to eq(destination_repository)
      end

      it "casts the enabled flag from the CSV" do
        service.call

        expect(Job.find_by!(name: "Daily backup").enabled).to be(true)
        expect(Job.find_by!(name: "Ad hoc sync").enabled).to be(false)
      end

      it "is idempotent" do
        expect { 2.times { service.call } }.to change(Job, :count).by(2)
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
