# frozen_string_literal: true

RSpec.describe "Notifications" do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /notifications" do
    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "renders the index page" do
        get notifications_path
        expect(response).to have_http_status(:ok)
      end

      it "filters by query" do
        match    = create(:notification, user:, name: "Production Slack")
        no_match = create(:notification, user:, name: "Staging email")

        get notifications_path, params: { query: "production" }

        expect(response.body).to include(match.name)
        expect(response.body).not_to include(no_match.name)
      end

      context "when feature is disabled" do
        before { Configuration.set("notifications", false) }

        after { Configuration.set("notifications", true) }

        it "returns 404" do
          get notifications_path
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get notifications_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /notifications" do
    let(:valid_params) { { notification: { name: "Slack", url: "slack://x/y/z/#chan", enabled: true } } }

    before { sign_in user, scope: :user }

    it "creates the notification for the current user" do
      expect { post notifications_path, params: valid_params }
        .to change(user.notifications, :count).by(1)

      expect(response).to redirect_to(notifications_path)
    end

    it "renders new with errors when invalid" do
      post notifications_path, params: { notification: { name: "", url: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /notifications/:id" do
    let(:notification) { create(:notification, user:, url: "slack://orig/url") }

    before { sign_in user, scope: :user }

    it "updates name" do
      patch notification_path(notification), params: { notification: { name: "New" } }

      expect(notification.reload.name).to eq("New")
    end

    it "does not clear url when blank" do
      expect do
        patch notification_path(notification), params: { notification: { url: "" } }
      end.not_to(change { notification.reload.url })
    end

    it "forbids updates to other users' notifications" do
      other = create(:notification, user: other_user)

      patch notification_path(other), params: { notification: { name: "Hacked" } }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /notifications/:id" do
    let!(:notification) { create(:notification, user:) }

    before { sign_in user, scope: :user }

    it "destroys" do
      expect { delete notification_path(notification) }
        .to change(Notification, :count).by(-1)
    end

    it "forbids destroy of other users' notifications" do
      other = create(:notification, user: other_user)

      delete notification_path(other)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /notifications/new" do
    before { sign_in user, scope: :user }

    it "renders" do
      get new_notification_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /notifications/:id/edit" do
    let(:notification) { create(:notification, user:) }

    before { sign_in user, scope: :user }

    it "renders" do
      get edit_notification_path(notification)
      expect(response).to have_http_status(:ok)
    end

    it "forbids editing other users' notifications" do
      other = create(:notification, user: other_user)

      get edit_notification_path(other)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /notifications/test" do
    before { sign_in user, scope: :user }

    it "returns a Turbo Stream response when URL is missing" do
      post test_notifications_path, params: { url: "" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(I18n.t("notifications.test.missing_url"))
    end

    it "returns a Turbo Stream response with success on success" do
      allow(Notifications::TestService).to receive(:call).and_return(success: true, message: "ok")

      post test_notifications_path, params: { url: "slack://x/y/z/#chan" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(I18n.t("notifications.test.success"))
    end

    it "returns a Turbo Stream response with failure on error" do
      allow(Notifications::TestService).to receive(:call).and_return(success: false, message: "Connection denied")

      post test_notifications_path, params: { url: "slack://x/y/z/#chan" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("Connection denied")
    end
  end

  describe "POST /notifications/:id/test" do
    let(:notification) { create(:notification, user:) }

    before { sign_in user, scope: :user }

    it "returns a Turbo Stream response with success on success" do
      allow(Notifications::TestService).to receive(:call).and_return(success: true, message: "ok")

      post test_notification_path(notification), headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(I18n.t("notifications.test.success"))
    end

    it "returns a Turbo Stream response with failure on error" do
      allow(Notifications::TestService).to receive(:call).and_return(success: false, message: "denied")

      post test_notification_path(notification), headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("denied")
    end

    it "forbids testing other users' notifications" do
      other = create(:notification, user: other_user)

      post test_notification_path(other), headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:forbidden)
    end
  end
end
