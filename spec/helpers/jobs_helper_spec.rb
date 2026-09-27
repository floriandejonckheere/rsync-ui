# frozen_string_literal: true

RSpec.describe JobsHelper do
  describe "#implied_options_data" do
    it "returns the implied options for an implying option" do
      expect(helper.implied_options_data(:opt_append)).to eq(
        implied_options_target: "source",
        action: "implied-options#sync",
        implies: "opt_inplace",
      )
    end

    it "returns an empty hash for other options" do
      expect(helper.implied_options_data(:opt_recursive)).to eq({})
    end
  end
end
