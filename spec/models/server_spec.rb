# frozen_string_literal: true

RSpec.describe Server do
  subject(:server) { build(:server) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:host) }
    it { is_expected.to validate_presence_of(:port) }
    it { is_expected.to validate_presence_of(:username) }

    it { is_expected.to validate_numericality_of(:port).only_integer.is_greater_than(0).is_less_than(65_536) }

    describe "exclusive credentials" do
      context "when password is present and ssh_key is absent" do
        subject(:server) { build(:server, password: "secret", ssh_key: nil) }

        it { is_expected.to be_valid }
      end

      context "when ssh_key is present and password is absent" do
        subject(:server) { build(:server, :with_ssh_key) }

        it { is_expected.to be_valid }
      end

      context "when both are present" do
        subject(:server) { build(:server, password: "secret", ssh_key: "key") }

        it { is_expected.not_to be_valid }

        it "adds an error on base" do
          server.valid?

          expect(server.errors[:base]).to include(
            I18n.t("activerecord.errors.models.server.attributes.base.exclusive_credentials"),
          )
        end
      end

      context "when neither is present" do
        subject(:server) { build(:server, password: nil, ssh_key: nil) }

        it { is_expected.not_to be_valid }

        it "adds an error on base" do
          server.valid?

          expect(server.errors[:base]).to include(
            I18n.t("activerecord.errors.models.server.attributes.base.exclusive_credentials"),
          )
        end
      end
    end

    describe "valid SSH key" do
      context "when ssh_key is a valid unencrypted OpenSSH private key" do
        subject(:server) { build(:server, :with_ssh_key) }

        it { is_expected.to be_valid }
      end

      context "when ssh_key is not a valid OpenSSH private key" do
        subject(:server) { build(:server, password: nil, ssh_key:) }

        let(:ssh_key) { "not-a-valid-key" }

        it { is_expected.not_to be_valid }

        it "adds an error on ssh_key" do
          server.validate

          expect(server.errors[:ssh_key]).to include I18n.t("activerecord.errors.models.server.attributes.ssh_key.ssh_key_invalid")
        end
      end

      context "when ssh_key is protected by a passphrase" do
        subject(:server) { build(:server, password: nil, ssh_key:) }

        let(:ssh_key) { Rails.root.join("spec/support/fixtures/ssh_key_with_passphrase").read }

        it { is_expected.not_to be_valid }

        it "adds an error on ssh_key" do
          server.validate

          expect(server.errors[:ssh_key]).to include I18n.t("activerecord.errors.models.server.attributes.ssh_key.ssh_key_passphrase")
        end
      end
    end
  end

  describe "callbacks" do
    describe "SSH key normalization" do
      it "normalizes line endings and whitespace before validation" do
        ssh_key = Rails.root.join("spec/support/fixtures/ssh_key").read
        dirty_key = "  #{ssh_key.gsub("\n", "\r\n").strip}\n\n"
        server = build(:server, password: nil, ssh_key: dirty_key)

        server.validate

        expect(server.ssh_key).to eq ssh_key
      end
    end
  end
end
