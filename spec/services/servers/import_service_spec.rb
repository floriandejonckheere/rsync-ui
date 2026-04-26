# frozen_string_literal: true

RSpec.describe Servers::ImportService do
  subject(:service) { described_class.new(path: tmp_path) }

  let(:tmp_path) { Pathname.new(Dir.mktmpdir) }
  let(:user) { create(:user) }

  after { FileUtils.remove_entry(tmp_path) }

  describe "#call" do
    context "when the CSV file exists" do
      before do
        tmp_path.join("02_servers.csv").write(<<~CSV)
          name,host,port,username,password,ssh_key,user_email
          Production,prod.example.com,22,deploy,secret,,#{user.email}
          Staging,staging.example.com,2222,deploy,secret,,#{user.email}
        CSV
      end

      it "creates servers from the CSV" do
        expect { service.call }.to change(Server, :count).by(2)
      end

      it "associates servers with the correct user" do
        service.call

        server = Server.find_by!(name: "Production")

        expect(server.user).to eq(user)
      end

      it "sets server attributes from the CSV" do
        service.call

        server = Server.find_by!(name: "Production")

        expect(server.host).to eq("prod.example.com")
        expect(server.port).to eq(22)
        expect(server.username).to eq("deploy")
      end

      it "is idempotent" do
        expect { 2.times { service.call } }.to change(Server, :count).by(2)
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
