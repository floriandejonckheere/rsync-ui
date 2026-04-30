# frozen_string_literal: true

RSpec.describe "Registrations" do
  let(:user) { create(:user, password: "old_password") }

  describe "PATCH /users" do
    context "when unauthenticated" do
      it "redirects to sign in" do
        patch user_registration_path, params: { user: { password: "new_password", password_confirmation: "new_password" } }

        expect(response).to redirect_to new_user_session_path
      end
    end

    context "when authenticated" do
      before { sign_in user, scope: :user }

      context "with matching passwords" do
        it "updates the user password" do
          patch user_registration_path, params: { user: { password: "new_password", password_confirmation: "new_password" } }

          expect(user.reload).to be_valid_password "new_password"
        end

        it "redirects to the settings page" do
          patch user_registration_path, params: { user: { password: "new_password", password_confirmation: "new_password" } }

          expect(response).to redirect_to(edit_user_registration_path)
        end
      end

      context "with mismatched passwords" do
        it "does not update the password" do
          patch user_registration_path, params: { user: { password: "new_password", password_confirmation: "wrong" } }

          expect(user.reload).to be_valid_password "old_password"
        end

        it "renders the edit page with errors" do
          patch user_registration_path, params: { user: { password: "new_password", password_confirmation: "wrong" } }

          expect(response).to have_http_status :unprocessable_content
        end
      end
    end
  end

  describe "DELETE /users" do
    context "when unauthenticated" do
      it "redirects to sign in" do
        delete user_registration_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "returns forbidden" do
        delete user_registration_path

        expect(response).to have_http_status(:forbidden)
      end

      it "does not delete the user" do
        expect { delete user_registration_path }
          .not_to(change(User, :count))
      end
    end
  end
end
