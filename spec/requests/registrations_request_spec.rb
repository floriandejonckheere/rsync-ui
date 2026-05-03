# frozen_string_literal: true

RSpec.describe "Registrations" do
  let(:user) { create(:user, first_name: "John", last_name: "Doe", email: "john@example.com", password: "old_password") }

  describe "PATCH /users" do
    context "when unauthenticated" do
      it "redirects to sign in" do
        patch user_registration_path, params: { user: { first_name: "Jane" } }

        expect(response).to redirect_to new_user_session_path
      end
    end

    context "when authenticated" do
      before { sign_in user, scope: :user }

      context "without password" do
        it "updates profile fields" do
          patch user_registration_path, params: { user: { first_name: "Jane", last_name: "Smith", email: "jane@example.com" } }

          expect(user.reload).to have_attributes(first_name: "Jane", last_name: "Smith", email: "jane@example.com")
        end

        it "does not change the password" do
          patch user_registration_path, params: { user: { first_name: "Jane", last_name: "Smith", email: "jane@example.com" } }

          expect(user.reload).to be_valid_password "old_password"
        end

        it "redirects to the settings page" do
          patch user_registration_path, params: { user: { first_name: "Jane", last_name: "Smith", email: "jane@example.com" } }

          expect(response).to redirect_to(root_path)
        end
      end

      context "with matching passwords" do
        it "updates the user password" do
          patch user_registration_path, params: { user: { first_name: "John", last_name: "Doe", email: "john@example.com", password: "new_password", password_confirmation: "new_password" } }

          expect(user.reload).to be_valid_password "new_password"
        end

        it "updates profile fields alongside the password" do
          patch user_registration_path, params: { user: { first_name: "Jane", last_name: "Smith", email: "jane@example.com", password: "new_password", password_confirmation: "new_password" } }

          expect(user.reload).to have_attributes(first_name: "Jane", last_name: "Smith", email: "jane@example.com")
        end

        it "redirects to the settings page" do
          patch user_registration_path, params: { user: { first_name: "John", last_name: "Doe", email: "john@example.com", password: "new_password", password_confirmation: "new_password" } }

          expect(response).to redirect_to(root_path)
        end
      end

      context "with mismatched passwords" do
        it "does not update the password" do
          patch user_registration_path, params: { user: { first_name: "John", last_name: "Doe", email: "john@example.com", password: "new_password", password_confirmation: "wrong" } }

          expect(user.reload).to be_valid_password "old_password"
        end

        it "renders the edit page with errors" do
          patch user_registration_path, params: { user: { first_name: "John", last_name: "Doe", email: "john@example.com", password: "new_password", password_confirmation: "wrong" } }

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
