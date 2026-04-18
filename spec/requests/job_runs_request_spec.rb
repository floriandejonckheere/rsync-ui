# frozen_string_literal: true

RSpec.describe "JobRuns" do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /job_runs" do
    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "renders the index page" do
        get job_runs_path

        expect(response).to have_http_status(:ok)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get job_runs_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "DELETE /job_runs/:id" do
    let!(:job_run) { create(:job_run, :completed, user:) }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "destroys the job run and redirects to the index" do
        expect { delete job_run_path(job_run) }
          .to change(JobRun, :count).by(-1)

        expect(response).to redirect_to(job_runs_path)
      end

      it "displays success message" do
        delete job_run_path(job_run)

        follow_redirect!

        expect(response.body).to include(I18n.t("job_runs.destroy.success"))
      end

      context "when job run is not deletable" do
        let!(:job_run) { create(:job_run, :running, user:) }

        it "returns unprocessable content" do
          delete job_run_path(job_run)

          expect(response).to have_http_status(:unprocessable_content)
        end

        it "does not destroy the job run" do
          expect { delete job_run_path(job_run) }
            .not_to change(JobRun, :count)
        end
      end
    end

    context "when job run belongs to another user" do
      let!(:job_run) { create(:job_run, :completed, user: other_user) }

      before { sign_in user, scope: :user }

      it "returns forbidden" do
        delete job_run_path(job_run)

        expect(response).to have_http_status(:forbidden)
      end

      it "does not destroy the job run" do
        expect { delete job_run_path(job_run) }
          .not_to change(JobRun, :count)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        delete job_run_path(job_run)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /job_runs/:id/cancel" do
    let(:job_run) { create(:job_run, :pending, user:) }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "raises NotImplementedError" do
        expect { patch cancel_job_run_path(job_run) }
          .to raise_error(NotImplementedError)
      end
    end

    context "when job run belongs to another user" do
      let(:job_run) { create(:job_run, :pending, user: other_user) }

      before { sign_in user, scope: :user }

      it "returns forbidden" do
        patch cancel_job_run_path(job_run)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        patch cancel_job_run_path(job_run)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
