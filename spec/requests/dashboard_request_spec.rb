# frozen_string_literal: true

RSpec.describe "Dashboard" do
  describe "GET /index" do
    it "renders the index page" do
      get "/"

      expect(response).to have_http_status(:ok)
    end
  end
end
