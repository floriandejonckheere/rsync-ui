# frozen_string_literal: true

RSpec.describe "Dashboard" do
  let(:user) { create(:user) }

  before { sign_in user, scope: :user }

  describe "GET /" do
    it "renders successfully" do
      get root_path

      expect(response).to have_http_status(:ok)
    end

    context "when notifications are enabled" do
      with_configuration "notifications" => true

      it "shows the notifications menu item" do
        get root_path

        expect(response.body).to include I18n.t("notifications.title")
      end
    end

    context "when notifications are disabled" do
      with_configuration "notifications" => false

      it "hides the notifications menu item" do
        get root_path

        expect(response.body).not_to include I18n.t("notifications.title")
      end
    end
  end
end
