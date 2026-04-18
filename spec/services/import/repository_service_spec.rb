# frozen_string_literal: true

RSpec.describe Import::RepositoryService do
  subject(:service) { described_class.new(path: tmp_path) }

  let(:tmp_path) { Pathname.new(Dir.mktmpdir) }
  let(:user) { create(:user) }
  let(:server) { create(:server, user:, name: "Production") }

  after { FileUtils.remove_entry(tmp_path) }

  describe "#call" do
    context "when the CSV file exists" do
      before do
        server

        tmp_path.join("03_repositories.csv").write(<<~CSV)
          name,description,path,read_only,repository_type,server_name,user_email
          System,System files,/etc,false,local,,#{user.email}
          Off-site backup,Remote backup target,/srv/backups,true,remote,Production,#{user.email}
        CSV
      end

      it "creates repositories from the CSV" do
        expect { service.call }.to change(Repository, :count).by(2)
      end

      it "creates local repositories without a server" do
        service.call

        repository = Repository.find_by!(name: "System")

        expect(repository.user).to eq(user)
        expect(repository.repository_type).to eq("local")
        expect(repository.server).to be_nil
      end

      it "associates remote repositories with the resolved server" do
        service.call

        repository = Repository.find_by!(name: "Off-site backup")

        expect(repository.repository_type).to eq("remote")
        expect(repository.server).to eq(server)
      end

      it "sets repository attributes from the CSV" do
        service.call

        repository = Repository.find_by!(name: "Off-site backup")

        expect(repository.description).to eq("Remote backup target")
        expect(repository.path).to eq("/srv/backups")
        expect(repository.read_only).to be(true)
      end

      it "is idempotent" do
        expect { 2.times { service.call } }.to change(Repository, :count).by(2)
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
