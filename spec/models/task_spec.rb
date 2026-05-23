# frozen_string_literal: true

RSpec.describe Task do
  subject(:task) { build(:task) }

  describe "associations" do
    it { is_expected.to belong_to(:last_run_by).class_name("User").optional }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:class_name) }
    it { is_expected.to validate_uniqueness_of(:name) }
  end

  describe "enums" do
    it "defines status enum" do
      expect(task).to define_enum_for(:status)
        .with_values(running: "running", completed: "completed", failed: "failed")
        .backed_by_column_of_type(:string)
    end
  end
end
