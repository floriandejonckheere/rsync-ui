# frozen_string_literal: true

RSpec.describe Import::UserService do
  subject(:service) { described_class.new(path: tmp_path) }

  let(:tmp_path) { Pathname.new(Dir.mktmpdir) }

  after { FileUtils.remove_entry(tmp_path) }

  describe "#call" do
    context "when the CSV file exists" do
      before do
        tmp_path.join("01_users.csv").write(<<~CSV)
          email,first_name,last_name,password,role
          jane@example.com,Jane,Doe,password,user
          john@example.com,John,Doe,password,admin
        CSV
      end

      it "creates users from the CSV" do
        expect { service.call }.to change(User, :count).by(2)
      end

      it "sets user attributes from the CSV" do
        service.call

        user = User.find_by!(email: "jane@example.com")

        expect(user.first_name).to eq("Jane")
        expect(user.last_name).to eq("Doe")
        expect(user.role).to eq("user")
      end

      it "is idempotent" do
        expect { 2.times { service.call } }.to change(User, :count).by(2)
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
