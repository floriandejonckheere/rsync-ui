# frozen_string_literal: true

RSpec.describe Servers::UnreachableError do
  subject(:error) { described_class.new(server: "NAS") }

  it { is_expected.to be_a ApplicationError }

  it "has a translated message" do
    expect(error.message).to eq "Server unreachable: Could not reach NAS"
  end
end
