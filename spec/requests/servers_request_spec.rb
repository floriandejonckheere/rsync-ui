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

      context "when a query parameter is present" do
        it "filters servers by name" do
          matching_server = create(:server, user:, name: "Production server")
          non_matching_server = create(:server, user:, name: "Staging")

          get servers_path, params: { query: "production" }

          expect(response.body).to include(matching_server.name)
          expect(response.body).not_to include(non_matching_server.name)
        end

        it "filters servers by description" do
          matching_server = create(:server, user:, description: "Primary web server")
          non_matching_server = create(:server, user:, description: "Backup storage")

          get servers_path, params: { query: "primary" }

          expect(response.body).to include(matching_server.description)
          expect(response.body).not_to include(non_matching_server.description)
        end

        it "filters servers by host" do
          matching_server = create(:server, user:, host: "prod.example.com")
          non_matching_server = create(:server, user:, host: "staging.example.com")

          get servers_path, params: { query: "prod.example" }

          expect(response.body).to include(matching_server.host)
          expect(response.body).not_to include(non_matching_server.host)
        end

        it "is case insensitive" do
          server = create(:server, user:, name: "Production server")

          get servers_path, params: { query: "PRODUCTION" }

          expect(response.body).to include(server.name)
        end

        it "handles special SQL characters safely" do
          server = create(:server, user:, name: "$$$ server")

          get servers_path, params: { query: "$$$" }

          expect(response).to have_http_status(:ok)
          expect(response.body).to include(server.name)
        end

        it "returns empty results for non-matching query" do
          create(:server, user:, name: "Some Server")

          get servers_path, params: { query: "nonexistent" }

          expect(response).to have_http_status(:ok)
        end
      end

      context "when sort parameters are present" do
        it "sorts servers by name ascending" do
          zebra = create(:server, user:, name: "Zebra server")
          alpha = create(:server, user:, name: "Alpha server")

          get servers_path, params: { sort: "name", direction: "asc" }

          expect(response.body.index(alpha.name)).to be < response.body.index(zebra.name)
        end

        it "sorts servers by name descending" do
          zebra = create(:server, user:, name: "Zebra server")
          alpha = create(:server, user:, name: "Alpha server")

          get servers_path, params: { sort: "name", direction: "desc" }

          expect(response.body.index(zebra.name)).to be < response.body.index(alpha.name)
        end

        it "sorts servers by host ascending" do
          z_server = create(:server, user:, host: "z.example.com")
          a_server = create(:server, user:, host: "a.example.com")

          get servers_path, params: { sort: "host", direction: "asc" }

          expect(response.body.index(a_server.host)).to be < response.body.index(z_server.host)
        end

        it "falls back to default name sort when direction is invalid" do
          create(:server, user:, name: "Beta server")

          get servers_path, params: { sort: "name", direction: "invalid" }

          expect(response).to have_http_status(:ok)
        end

        it "falls back to default sort when column is not allowed" do
          create(:server, user:, name: "Beta server")

          get servers_path, params: { sort: "password", direction: "asc" }

          expect(response).to have_http_status(:ok)
        end
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

  describe "POST /servers/connection" do
    let(:ssh_session) { instance_double(Net::SSH::Connection::Session) }

    before do
      allow(Net::SSH)
        .to receive(:start)
        .and_yield(ssh_session)

      allow(ssh_session)
        .to receive(:exec!)
        .and_return("ok\n")
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        post connection_servers_path, params: { host: "example.com", port: 22, username: "admin", password: "secret" }

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated (new server form, no server_id)" do
      before { sign_in user, scope: :user }

      it "returns a Turbo Stream response" do
        post connection_servers_path,
             params: { host: "example.com", port: 22, username: "admin", password: "secret" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end

      it "renders a success notification when SSH connects" do
        post connection_servers_path,
             params: { host: "example.com", port: 22, username: "admin", password: "secret" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to include(I18n.t("servers.connection.success"))
      end

      it "uses password when provided" do
        post connection_servers_path,
             params: { host: "example.com", port: 22, username: "admin", password: "password" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(Net::SSH)
          .to have_received(:start)
          .with(anything, anything, hash_including(password: "password"))

        expect(response.body).to include(I18n.t("servers.connection.success"))
      end

      it "uses ssh_key when provided" do
        post connection_servers_path,
             params: { host: "example.com", port: 22, username: "admin", ssh_key: "ssh_key" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(Net::SSH)
          .to have_received(:start)
          .with(anything, anything, hash_including(key_data: ["ssh_key"]))

        expect(response.body).to include(I18n.t("servers.connection.success"))
      end

      it "renders a failure notification when SSH fails" do
        allow(Net::SSH)
          .to receive(:start)
          .and_raise(Net::SSH::AuthenticationFailed, "Authentication failed")

        post connection_servers_path,
             params: { host: "example.com", port: 22, username: "admin", password: "wrong" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to include(I18n.t("servers.connection.failure"))
        expect(response.body).to include("Net::SSH::AuthenticationFailed")
      end

      it "renders a failure notification when host is missing" do
        post connection_servers_path,
             params: { port: 22, username: "admin", password: "secret" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(Net::SSH)
          .not_to have_received(:start)

        expect(response.body).to include(I18n.t("servers.connection.failure"))
        expect(response.body).to include(I18n.t("servers.connection.missing_details"))
      end

      it "does not render a failure notification when port is missing" do
        post connection_servers_path,
             params: { host: "example.com", username: "admin", password: "secret" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(Net::SSH)
          .to have_received(:start)
      end

      it "renders a failure notification when username is missing" do
        post connection_servers_path,
             params: { host: "example.com", port: 22, password: "secret" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(Net::SSH)
          .not_to have_received(:start)

        expect(response.body).to include(I18n.t("servers.connection.failure"))
        expect(response.body).to include(I18n.t("servers.connection.missing_details"))
      end

      it "renders a failure notification when both password and ssh_key are missing" do
        post connection_servers_path,
             params: { host: "example.com", port: 22, username: "admin" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(Net::SSH)
          .not_to have_received(:start)

        expect(response.body).to include(I18n.t("servers.connection.failure"))
        expect(response.body).to include(I18n.t("servers.connection.missing_details"))
      end
    end

    context "when authenticated (edit form, server_id provided)" do
      let(:server) { create(:server, :with_password, user:) }

      before { sign_in user, scope: :user }

      it "succeeds using submitted credentials when present" do
        post connection_servers_path,
             params: { server_id: server.id, host: server.host, port: server.port, username: server.username, password: "newpass" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to include(I18n.t("servers.connection.success"))
      end

      it "falls back to stored credentials when password and ssh_key params are blank" do
        post connection_servers_path,
             params: { server_id: server.id, host: server.host, port: server.port, username: server.username, password: "", ssh_key: "" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(Net::SSH)
          .to have_received(:start)
          .with(anything, anything, hash_including(password: server.password))

        expect(response.body).to include(I18n.t("servers.connection.success"))
      end

      context "when server belongs to another user" do
        let(:server) { create(:server, :with_password, user: other_user) }

        it "returns forbidden" do
          post connection_servers_path,
               params: { server_id: server.id, host: server.host, port: server.port, username: server.username, password: "" },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end
end
