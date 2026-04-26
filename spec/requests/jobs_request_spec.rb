# frozen_string_literal: true

RSpec.describe "Jobs" do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /jobs" do
    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "renders the index page" do
        get jobs_path

        expect(response).to have_http_status(:ok)
      end

      context "when sort parameters are present" do
        it "sorts jobs by name ascending" do
          z_job = create(:job, user:, name: "Zebra job")
          a_job = create(:job, user:, name: "Alpha job")

          get jobs_path, params: { sort: "name", direction: "asc" }

          expect(response.body.index(a_job.name)).to be < response.body.index(z_job.name)
        end

        it "sorts jobs by name descending" do
          z_job = create(:job, user:, name: "Zebra job")
          a_job = create(:job, user:, name: "Alpha job")

          get jobs_path, params: { sort: "name", direction: "desc" }

          expect(response.body.index(z_job.name)).to be < response.body.index(a_job.name)
        end

        it "falls back to default sort when column is not allowed" do
          create(:job, user:)

          get jobs_path, params: { sort: "opt_delete", direction: "asc" }

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get jobs_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /jobs/new" do
    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "renders the new page" do
        get new_job_path

        expect(response).to have_http_status(:ok)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get new_job_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /jobs" do
    let(:source_repository) { create(:repository, user:) }
    let(:destination_repository) { create(:repository, user:) }
    let(:valid_params) do
      {
        job: {
          name: "Daily Backup",
          description: "Nightly sync",
          source_repository_id: source_repository.id,
          destination_repository_id: destination_repository.id,
          schedule: "0 2 * * *",
          enabled: true,
        },
      }
    end

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "creates the job for the current user and redirects to the index" do
        expect { post jobs_path, params: valid_params }
          .to change(user.jobs, :count).by(1)

        expect(response).to redirect_to(jobs_path)
      end

      it "displays success message" do
        post jobs_path, params: valid_params

        follow_redirect!

        expect(response.body).to include(I18n.t("jobs.create.success"))
      end

      context "with invalid params" do
        let(:invalid_params) do
          {
            job: {
              name: "",
              source_repository_id: source_repository.id,
              destination_repository_id: source_repository.id,
              schedule: "invalid",
            },
          }
        end

        it "renders the new page with errors" do
          post jobs_path, params: invalid_params

          expect(response).to have_http_status(:unprocessable_content)
        end

        it "does not create a job" do
          expect { post jobs_path, params: invalid_params }
            .not_to change(Job, :count)
        end
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        post jobs_path, params: valid_params

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /jobs/:id/edit" do
    let(:job) { create(:job, user:) }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "renders the edit page" do
        get edit_job_path(job)

        expect(response).to have_http_status(:ok)
      end
    end

    context "when job belongs to another user" do
      let(:job) { create(:job, user: other_user) }

      before { sign_in user, scope: :user }

      it "returns forbidden" do
        get edit_job_path(job)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get edit_job_path(job)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /jobs/:id" do
    let(:job) { create(:job, user:) }
    let(:update_params) { { job: { name: "Updated Job", enabled: false } } }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "updates the job and redirects to the index" do
        patch job_path(job), params: update_params

        expect(job.reload.name).to eq("Updated Job")
        expect(job.enabled).to be(false)
        expect(response).to redirect_to(jobs_path)
      end

      it "displays success message" do
        patch job_path(job), params: update_params

        follow_redirect!

        expect(response.body).to include(I18n.t("jobs.update.success"))
      end

      context "with invalid params" do
        let(:invalid_params) { { job: { name: "", schedule: "invalid" } } }

        it "renders the edit page with errors" do
          patch job_path(job), params: invalid_params

          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    context "when job belongs to another user" do
      let(:job) { create(:job, user: other_user) }

      before { sign_in user, scope: :user }

      it "returns forbidden" do
        patch job_path(job), params: update_params

        expect(response).to have_http_status(:forbidden)
      end

      it "does not update the job" do
        expect do
          patch job_path(job), params: update_params
        end.not_to(change { job.reload.name })
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        patch job_path(job), params: update_params

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "DELETE /jobs/:id" do
    let!(:job) { create(:job, user:) }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "destroys the job and redirects to the index" do
        expect do
          delete job_path(job)
        end.to change(Job, :count).by(-1)

        expect(response).to redirect_to(jobs_path)
      end

      it "displays success message" do
        delete job_path(job)

        follow_redirect!

        expect(response.body).to include(I18n.t("jobs.destroy.success"))
      end
    end

    context "when job belongs to another user" do
      let!(:job) { create(:job, user: other_user) }

      before { sign_in user, scope: :user }

      it "returns forbidden" do
        delete job_path(job)

        expect(response).to have_http_status(:forbidden)
      end

      it "does not destroy the job" do
        expect do
          delete job_path(job)
        end.not_to change(Job, :count)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        delete job_path(job)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
