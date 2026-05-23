# frozen_string_literal: true

RSpec.describe "Tasks" do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:task) { create(:task) }

  describe "POST /tasks/:id/run" do
    context "when user is an admin" do
      before { sign_in admin, scope: :user }

      it "returns a Turbo Stream response on success" do
        allow(Tasks::ExecuteService).to receive(:call).and_return(success: true)

        post run_task_path(task), headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end

      it "returns a Turbo Stream response on failure" do
        allow(Tasks::ExecuteService).to receive(:call).and_return(success: false, message: "Something failed")

        post run_task_path(task), headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end
    end

    context "when user is not an admin" do
      before { sign_in user, scope: :user }

      it "returns forbidden" do
        post run_task_path(task), headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        post run_task_path(task)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
