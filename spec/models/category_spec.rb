# frozen_string_literal: true

RSpec.describe Category do
  subject(:category) { build(:category) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_inclusion_of(:categorizable_type).in_array(described_class::CATEGORIZABLE_TYPES) }

    it "is invalid with a case-insensitively duplicate name for the same user and type" do
      existing = create(:category, name: "Backups")

      category = build(:category, user: existing.user, name: "backups")

      expect(category).not_to be_valid
    end

    it "is valid with a duplicate name for another type" do
      existing = create(:category, name: "Backups")

      category = build(:category, user: existing.user, categorizable_type: "Server", name: "Backups")

      expect(category).to be_valid
    end

    it "is valid with a duplicate name for another user" do
      create(:category, name: "Backups")

      category = build(:category, name: "Backups")

      expect(category).to be_valid
    end
  end

  describe "normalization" do
    it "strips surrounding whitespace from the name" do
      category = build(:category, name: "  Backups  ")

      expect(category.name).to eq("Backups")
    end
  end

  describe ".named" do
    it "finds categories case-insensitively" do
      category = create(:category, name: "Backups")

      expect(described_class.named(" BACKUPS ")).to contain_exactly(category)
    end
  end

  describe "#categorizable_class" do
    it "returns the model class of the categorizable type" do
      category = build(:category, categorizable_type: "Server")

      expect(category.categorizable_class).to eq(Server)
    end

    it "returns nil for a type outside the allowlist" do
      category = build(:category, categorizable_type: "User")

      expect(category.categorizable_class).to be_nil
    end
  end

  describe "#records" do
    it "returns the records of the categorizable type in the category" do
      job = create(:job, category_name: "Backups")

      expect(job.category.records).to contain_exactly(job)
    end
  end
end
