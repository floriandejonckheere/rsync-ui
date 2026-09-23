# frozen_string_literal: true

RSpec.describe Repository do
  subject(:repository) { build(:repository) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:server).optional }

    it { is_expected.to have_many(:source_jobs).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:destination_jobs).dependent(:restrict_with_error) }
  end

  describe "normalization" do
    it "strips surrounding whitespace from the category" do
      repository = build(:repository, category_name: "  Production  ")

      repository.valid?

      expect(repository.category_name).to eq("Production")
    end

    it "normalizes a blank category to nil" do
      repository = build(:repository, category_name: "   ")

      repository.valid?

      expect(repository.category_name).to be_nil
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:path) }

    describe "server required for remote type" do
      context "when type is remote and server is present" do
        subject(:repository) { build(:repository, :remote) }

        it { is_expected.to be_valid }
      end

      context "when type is remote and server is absent" do
        subject(:repository) { build(:repository, repository_type: "remote", server: nil) }

        it { is_expected.not_to be_valid }

        it "adds an error on server" do
          repository.valid?

          expect(repository.errors[:server]).to be_present
        end
      end

      context "when type is local and server is absent" do
        subject(:repository) { build(:repository, :local) }

        it { is_expected.to be_valid }
      end

      context "when type is local and server is present" do
        subject(:repository) { build(:repository, :local, server: build(:server)) }

        it { is_expected.not_to be_valid }

        it "adds an error on server" do
          repository.valid?

          expect(repository.errors[:server]).to be_present
        end
      end
    end
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:repository_type).with_values(local: "local", remote: "remote").backed_by_column_of_type(:string) }
  end
end
