# frozen_string_literal: true

RSpec.describe "Servers" do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /servers" do
    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "renders the index page" do
        get servers_path

        expect(response).to have_http_status(:ok)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get servers_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /servers/new" do
    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "renders the new page" do
        get new_server_path

        expect(response).to have_http_status(:ok)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get new_server_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /servers" do
    let(:valid_params) { { server: { name: "My Server", host: "example.com", port: 22, username: "admin", password: "secret" } } }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "creates the server for the current user and redirects to the index" do
        expect { post servers_path, params: valid_params }
          .to change(user.servers, :count).by(1)

        expect(response).to redirect_to(servers_path)
      end

      it "displays success message" do
        post servers_path, params: valid_params

        follow_redirect!

        expect(response.body).to include(I18n.t("servers.create.success"))
      end

      context "with invalid params" do
        let(:invalid_params) { { server: { name: "", host: "", port: 22, username: "", password: "" } } }

        it "renders the new page with errors" do
          post servers_path, params: invalid_params

          expect(response).to have_http_status(:unprocessable_content)
        end

        it "does not create a server" do
          expect { post servers_path, params: invalid_params }
            .not_to change(Server, :count)
        end
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        post servers_path, params: valid_params

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /servers/:id/edit" do
    let(:server) { create(:server, user:) }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "renders the edit page" do
        get edit_server_path(server)

        expect(response).to have_http_status(:ok)
      end
    end

    context "when server belongs to another user" do
      let(:server) { create(:server, user: other_user) }

      before { sign_in user, scope: :user }

      it "returns forbidden" do
        get edit_server_path(server)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get edit_server_path(server)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /servers/:id" do
    let(:server) { create(:server, user:) }
    let(:update_params) { { server: { name: "Updated Server" } } }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "updates the server and redirects to the index" do
        patch server_path(server), params: update_params

        expect(server.reload.name).to eq("Updated Server")
        expect(response).to redirect_to(servers_path)
      end

      it "displays success message" do
        patch server_path(server), params: update_params

        follow_redirect!

        expect(response.body).to include(I18n.t("servers.update.success"))
      end

      it "does not clear password when left blank in params" do
        expect { patch server_path(server), params: { server: { name: "Updated", password: "" } } }
          .not_to(change { server.reload.password })
      end

      context "with invalid params" do
        let(:invalid_params) { { server: { name: "", host: "" } } }

        it "renders the edit page with errors" do
          patch server_path(server), params: invalid_params

          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    context "when server belongs to another user" do
      let(:server) { create(:server, user: other_user) }

      before { sign_in user, scope: :user }

      it "returns forbidden" do
        patch server_path(server), params: update_params

        expect(response).to have_http_status(:forbidden)
      end

      it "does not update the server" do
        expect do
          patch server_path(server), params: update_params
        end.not_to(change { server.reload.name })
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        patch server_path(server), params: update_params

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "DELETE /servers/:id" do
    let!(:server) { create(:server, user:) }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "destroys the server and redirects to the index" do
        expect do
          delete server_path(server)
        end.to change(Server, :count).by(-1)

        expect(response).to redirect_to(servers_path)
      end

      it "displays success message" do
        delete server_path(server)

        follow_redirect!

        expect(response.body).to include(I18n.t("servers.destroy.success"))
      end
    end

    context "when server belongs to another user" do
      let!(:server) { create(:server, user: other_user) }

      before { sign_in user, scope: :user }

      it "returns forbidden" do
        delete server_path(server)

        expect(response).to have_http_status(:forbidden)
      end

      it "does not destroy the server" do
        expect do
          delete server_path(server)
        end.not_to change(Server, :count)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        delete server_path(server)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
