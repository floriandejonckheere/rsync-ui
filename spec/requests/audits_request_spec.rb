# frozen_string_literal: true

RSpec.describe "Audits" do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  describe "GET /audits" do
    context "when authenticated as admin" do
      before { sign_in admin, scope: :user }

      it "renders the index page" do
        get audits_path

        expect(response).to have_http_status(:ok)
      end

      context "when filter by server" do
        it "filters by server_id" do
          server = create(:server)
          match = create(:audit, server:)
          no_match = create(:audit)

          get audits_path, params: { filter: { server_id: server.id } }

          expect(response.body).to include(match.id)
          expect(response.body).not_to include(no_match.id)
        end
      end

      context "when feature is disabled" do
        before { Configuration.set("audits", false) }

        after { Configuration.set("audits", true) }

        it "returns 404" do
          get audits_path

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "when authenticated as non-admin" do
      before { sign_in user, scope: :user }

      it "returns forbidden" do
        get audits_path

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get audits_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /audits/:id" do
    context "when authenticated as admin" do
      before { sign_in admin, scope: :user }

      it "renders the show page" do
        audit = create(:audit)

        get audit_path(audit)

        expect(response).to have_http_status(:ok)
      end

      context "when feature is disabled" do
        before { Configuration.set("audits", false) }

        after { Configuration.set("audits", true) }

        it "returns 404" do
          audit = create(:audit)

          get audit_path(audit)

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "when authenticated as non-admin" do
      before { sign_in user, scope: :user }

      it "returns forbidden" do
        audit = create(:audit)

        get audit_path(audit)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        audit = create(:audit)

        get audit_path(audit)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
