# frozen_string_literal: true

RSpec.describe ApplicationCable::Connection do
  let(:user) { create(:user) }

  context "when authenticated" do
    it "connects and identifies as the current user" do
      warden = double("warden") # rubocop:disable RSpec/VerifiedDoubles

      allow(warden)
        .to receive(:user)
        .with(:user)
        .and_return(user)

      connect "/cable", env: { "warden" => warden }

      expect(connection.current_user).to eq user
    end
  end

  context "when not authenticated" do
    it "rejects the connection" do
      warden = double("warden") # rubocop:disable RSpec/VerifiedDoubles

      allow(warden)
        .to receive(:user)
        .with(:user)
        .and_return(nil)

      expect do
        connect "/cable", env: { "warden" => warden }
      end.to have_rejected_connection
    end
  end
end
