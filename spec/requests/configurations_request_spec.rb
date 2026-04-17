# frozen_string_literal: true

RSpec.describe "Configurations" do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  describe "GET /configurations" do
    context "when user is an admin" do
      before { sign_in admin, scope: :user }

      it "renders the index page" do
        get configurations_path

        expect(response).to have_http_status(:ok)
      end
    end

    context "when user is not an admin" do
      before { sign_in user, scope: :user }

      it "returns forbidden" do
        get configurations_path

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        get configurations_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /configurations/:id" do
    subject(:configuration) { create(:configuration, key: "test.key") }

    context "when user is an admin" do
      before { sign_in admin, scope: :user }

      it "updates the configuration and redirects to configurations page" do
        patch configuration_path(configuration), params: { configuration: { value: "new-value" } }

        expect(configuration.reload.value).to eq "new-value"
        expect(response).to redirect_to(configurations_path)
      end

      it "displays success message" do
        patch configuration_path(configuration), params: { configuration: { value: "new-value" } }

        follow_redirect!

        expect(response.body).to include(I18n.t("configurations.update.success"))
      end
    end

    context "when user is not an admin" do
      before { sign_in user, scope: :user }

      it "returns forbidden" do
        patch configuration_path(configuration), params: { configuration: { value: "new-value" } }

        expect(response).to have_http_status(:forbidden)
      end

      it "does not update the configuration" do
        expect do
          patch configuration_path(configuration), params: { configuration: { value: "new-value" } }
        end.not_to(change { configuration.reload.value })
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        patch configuration_path(configuration), params: { configuration: { value: "new-value" } }

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
