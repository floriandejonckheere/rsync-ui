# frozen_string_literal: true

RSpec.describe "Dashboard" do
  let(:user) { create(:user) }

  before { sign_in user, scope: :user }

  describe "GET /" do
    it "renders successfully" do
      get root_path

      expect(response).to have_http_status(:ok)
    end
  end
end
