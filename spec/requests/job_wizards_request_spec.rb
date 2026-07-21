# frozen_string_literal: true

RSpec.describe "JobWizards" do
  let(:user) { create(:user) }

  before { sign_in user, scope: :user }

  describe "GET /job_wizard/:id" do
    it "renders the basics step" do
      get job_wizard_path(:basics)

      expect(response).to have_http_status(:ok)
    end

    it "redirects to the first incomplete step when skipping ahead" do
      get job_wizard_path(:schedule)

      expect(response).to redirect_to(job_wizard_path(:basics))
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        sign_out user

        get job_wizard_path(:basics)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "the local_to_local flow" do
    it "creates a job with two local repositories" do
      patch job_wizard_path(:basics), params: { job_wizard: { name: "Local Backup", description: "desc", sync_type: "local_to_local" } }
      expect(response).to redirect_to(job_wizard_path(:source))

      patch job_wizard_path(:source), params: { job_wizard: { path: "/data/source" } }
      expect(response).to redirect_to(job_wizard_path(:destination))

      patch job_wizard_path(:destination), params: { job_wizard: { path: "/data/destination" } }
      expect(response).to redirect_to(job_wizard_path(:schedule))

      expect do
        patch job_wizard_path(:schedule), params: { job_wizard: { schedule: "0 2 * * *", enabled: "1" } }
      end.to change(Job, :count).by(1).and change(Repository, :count).by(2)

      expect(response).to redirect_to(jobs_path)
      follow_redirect!
      expect(response.body).to include(I18n.t("job_wizards.update.success"))

      job = user.jobs.last
      expect(job.name).to eq("Local Backup")
      expect(job.source_repository).to be_local
      expect(job.destination_repository).to be_local
      expect(job.source_repository.path).to eq("/data/source")
      expect(job.destination_repository.path).to eq("/data/destination")
    end
  end

  describe "the local_to_remote flow with an existing server" do
    let!(:server) { create(:server, user:) }

    it "creates a job with a remote destination repository" do
      patch job_wizard_path(:basics), params: { job_wizard: { name: "Offsite Backup", sync_type: "local_to_remote" } }
      patch job_wizard_path(:source), params: { job_wizard: { path: "/data/source" } }
      expect(response).to redirect_to(job_wizard_path(:destination))

      patch job_wizard_path(:destination), params: { job_wizard: { path: "/remote/path", server_id: server.id } }
      expect(response).to redirect_to(job_wizard_path(:schedule))

      expect { patch job_wizard_path(:schedule), params: { job_wizard: {} } }
        .to change(Job, :count).by(1)

      job = user.jobs.last
      expect(job.destination_repository).to be_remote
      expect(job.destination_repository.server).to eq(server)
    end
  end

  describe "the remote_to_local flow creating a new server" do
    it "inserts a source_server step and creates the server" do
      patch job_wizard_path(:basics), params: { job_wizard: { name: "Pull Backup", sync_type: "remote_to_local" } }

      patch job_wizard_path(:source), params: { job_wizard: { path: "/remote/path", server_id: "new" } }
      expect(response).to redirect_to(job_wizard_path(:source_server))

      expect do
        patch job_wizard_path(:source_server), params: {
          job_wizard: {
            name: "New Server",
            host: "example.com",
            port: 22,
            username: "admin",
            password: "secret",
          },
        }
      end.to change(Server, :count).by(1)

      expect(response).to redirect_to(job_wizard_path(:destination))

      patch job_wizard_path(:destination), params: { job_wizard: { path: "/data/destination" } }
      expect(response).to redirect_to(job_wizard_path(:schedule))

      patch job_wizard_path(:schedule), params: { job_wizard: {} }

      job = user.jobs.last
      expect(job.source_repository).to be_remote
      expect(job.source_repository.server).to eq(Server.last)
    end
  end

  describe "validation errors" do
    it "re-renders the basics step when name is blank" do
      patch job_wizard_path(:basics), params: { job_wizard: { name: "", sync_type: "local_to_local" } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "re-renders the source step when path is blank" do
      patch job_wizard_path(:basics), params: { job_wizard: { name: "Job", sync_type: "local_to_local" } }

      patch job_wizard_path(:source), params: { job_wizard: { path: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "requires a server when the source is remote" do
      patch job_wizard_path(:basics), params: { job_wizard: { name: "Job", sync_type: "remote_to_local" } }

      patch job_wizard_path(:source), params: { job_wizard: { path: "/remote/path" } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "re-renders the schedule step with an invalid cron expression" do
      patch job_wizard_path(:basics), params: { job_wizard: { name: "Job", sync_type: "local_to_local" } }
      patch job_wizard_path(:source), params: { job_wizard: { path: "/data/source" } }
      patch job_wizard_path(:destination), params: { job_wizard: { path: "/data/destination" } }

      expect do
        patch job_wizard_path(:schedule), params: { job_wizard: { schedule: "not a cron" } }
      end.not_to change(Job, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
