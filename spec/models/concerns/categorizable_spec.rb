# frozen_string_literal: true

RSpec.describe Categorizable do
  let(:user) { create(:user) }

  describe "#category_name=" do
    it "creates a new category" do
      job = create(:job, user:, category_name: "Backups")

      expect(job.category).to have_attributes(user:, categorizable_type: "Job", name: "Backups")
    end

    it "reuses an existing category case-insensitively" do
      category = create(:category, user:, categorizable_type: "Job", name: "Backups")

      job = create(:job, user:, category_name: " backups ")

      expect(job.category).to eq(category)
    end

    it "does not reuse a category of another type" do
      category = create(:category, user:, categorizable_type: "Server", name: "Backups")

      job = create(:job, user:, category_name: "Backups")

      expect(job.category).not_to eq(category)
    end

    it "does not reuse a category of another user" do
      category = create(:category, categorizable_type: "Job", name: "Backups")

      job = create(:job, user:, category_name: "Backups")

      expect(job.category).not_to eq(category)
    end

    it "removes the category when blank" do
      job = create(:job, user:, category_name: "Backups")

      job.update!(category_name: "")

      expect(job.category).to be_nil
    end
  end

  describe "unused categories" do
    it "destroys the previous category when it is no longer used" do
      job = create(:job, user:, category_name: "Backups")
      category = job.category

      job.update!(category_name: "Mirrors")

      expect(Category.exists?(category.id)).to be(false)
    end

    it "keeps the previous category when it is still used" do
      job = create(:job, user:, category_name: "Backups")
      create(:job, user:, category_name: "Backups")

      job.update!(category_name: "Mirrors")

      expect(Category.named("Backups")).to exist
    end

    it "destroys the category when the last record is destroyed" do
      job = create(:job, user:, category_name: "Backups")

      job.destroy!

      expect(Category.named("Backups")).not_to exist
    end
  end

  describe ".grouped_by_category" do
    it "orders uncategorized records first, then by category name" do
      mirrors = create(:server, user:, name: "Alpha", category_name: "Mirrors")
      backups = create(:server, user:, name: "Beta", category_name: "Backups")
      uncategorized = create(:server, user:, name: "Gamma")

      expect(Server.order(:name).grouped_by_category).to eq([uncategorized, backups, mirrors])
    end
  end
end
