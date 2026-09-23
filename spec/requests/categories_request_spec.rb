# frozen_string_literal: true

RSpec.describe "Categories" do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "PATCH /categories/:id" do
    context "when not authenticated" do
      let(:category) { create(:category, user:) }

      it "redirects to the sign in page" do
        patch category_path(category), params: { category: { name: "Renamed" } }

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated as the owner" do
      let(:category) { create(:category, user:, categorizable_type: "Server", name: "Production") }

      before { sign_in user, scope: :user }

      it "renames the category" do
        patch category_path(category), params: { category: { name: "Staging" } }

        expect(category.reload.name).to eq("Staging")
      end

      it "redirects back to the index of the categorizable type" do
        patch category_path(category), params: { category: { name: "Staging" } }

        expect(response).to redirect_to(servers_path)
        expect(flash[:notice]).to eq(I18n.t("categories.update.success"))
      end

      it "redirects back to the referer" do
        referer = servers_url(page: 2, host: "www.example.com")

        patch category_path(category), params: { category: { name: "Staging" } }, headers: { "Referer" => referer }

        expect(response).to redirect_to(referer)
      end

      it "does not rename the category to a blank name" do
        patch category_path(category), params: { category: { name: " " } }

        expect(category.reload.name).to eq("Production")
        expect(flash[:alert]).to be_present
      end

      it "does not rename the category to an existing name" do
        create(:category, user:, categorizable_type: "Server", name: "Staging")

        patch category_path(category), params: { category: { name: "staging" } }

        expect(category.reload.name).to eq("Production")
        expect(flash[:alert]).to be_present
      end
    end

    context "when authenticated as another user" do
      let(:category) { create(:category, user: other_user) }

      before { sign_in user, scope: :user }

      it "returns forbidden" do
        patch category_path(category), params: { category: { name: "Renamed" } }

        expect(response).to have_http_status(:forbidden)
        expect(category.reload.name).not_to eq("Renamed")
      end
    end
  end
end
