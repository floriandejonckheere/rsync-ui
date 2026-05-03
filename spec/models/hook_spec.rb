# frozen_string_literal: true

RSpec.describe Hook do
  subject(:hook) { build(:hook) }

  describe "associations" do
    it { is_expected.to belong_to(:job) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:hook_type) }
    it { is_expected.to validate_presence_of(:command) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:hook_type).with_values(pre: "pre", post: "post", success: "success", failure: "failure").backed_by_column_of_type(:string) }
  end
end
