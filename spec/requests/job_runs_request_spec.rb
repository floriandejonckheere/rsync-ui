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

      context "when sort parameters are present" do
        it "sorts job runs by sequence ascending" do
          job = create(:job, user:)
          first_run = create(:job_run, :completed, user:, job:)
          second_run = create(:job_run, :completed, user:, job:)

          get job_runs_path, params: { sort: "sequence", direction: "asc" }

          expect(response.body.index(first_run.sequence.to_s)).to be < response.body.index(second_run.sequence.to_s)
        end

        it "sorts job runs by sequence descending" do
          job = create(:job, user:)
          first_run = create(:job_run, :completed, user:, job:)
          second_run = create(:job_run, :completed, user:, job:)

          get job_runs_path, params: { sort: "sequence", direction: "desc" }

          expect(response.body.index(second_run.sequence.to_s)).to be < response.body.index(first_run.sequence.to_s)
        end

        it "falls back to default sort when column is not allowed" do
          create(:job_run, :completed, user:)

          get job_runs_path, params: { sort: "trigger", direction: "asc" }

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get job_runs_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /job_runs/:id" do
    let(:job_run) { create(:job_run, :completed, user:) }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      context "when output is attached" do
        before { job_run.output.attach(io: StringIO.new("log content"), filename: "output.log", content_type: "text/plain") }

        it "renders the show page" do
          get job_run_path(job_run)

          expect(response).to have_http_status(:ok)
        end
      end

      context "when output is not attached" do
        it "redirects to the index" do
          get job_run_path(job_run)

          expect(response).to redirect_to(job_runs_path)
        end
      end
    end

    context "when job run belongs to another user" do
      let(:job_run) { create(:job_run, :completed, user: other_user) }

      before { sign_in user, scope: :user }

      it "returns forbidden" do
        get job_run_path(job_run)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get job_run_path(job_run)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /job_runs/:id/logs" do
    let(:job_run) { create(:job_run, :completed, user:) }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      context "when output is attached" do
        before { job_run.output.attach(io: StringIO.new("log content"), filename: "output.log", content_type: "text/plain") }

        it "redirects to the blob download URL" do
          get logs_job_run_path(job_run)

          expect(response).to have_http_status(:redirect)
        end
      end

      context "when output is not attached" do
        it "returns not found" do
          get logs_job_run_path(job_run)

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "when job run belongs to another user" do
      let(:job_run) { create(:job_run, :completed, user: other_user) }

      before { sign_in user, scope: :user }

      it "returns forbidden" do
        get logs_job_run_path(job_run)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get logs_job_run_path(job_run)

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

  describe "POST /job_runs" do
    let!(:job) { create(:job, user:) }

    before { allow(Jobs::ExecuteJob).to receive(:perform_later) }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "enqueues Jobs::ExecuteJob and redirects" do
        post job_runs_path, params: { job_id: job.id }

        expect(Jobs::ExecuteJob).to have_received(:perform_later).with(job, trigger: "manual")
        expect(response).to redirect_to(job_runs_path)
      end

      it "displays success message" do
        post job_runs_path, params: { job_id: job.id }
        follow_redirect!

        expect(response.body).to include(I18n.t("job_runs.create.success"))
      end

      context "when the job is disabled" do
        let!(:job) { create(:job, user:, enabled: false) }

        it "returns unprocessable content" do
          post job_runs_path, params: { job_id: job.id }

          expect(response).to have_http_status(:unprocessable_content)
        end

        it "does not enqueue Jobs::ExecuteJob" do
          post job_runs_path, params: { job_id: job.id }

          expect(Jobs::ExecuteJob).not_to have_received(:perform_later)
        end
      end
    end

    context "when job belongs to another user" do
      let!(:job) { create(:job, user: other_user) }

      before { sign_in user, scope: :user }

      it "returns forbidden" do
        post job_runs_path, params: { job_id: job.id }

        expect(response).to have_http_status(:forbidden)
      end

      it "does not enqueue Jobs::ExecuteJob" do
        post job_runs_path, params: { job_id: job.id }

        expect(Jobs::ExecuteJob).not_to have_received(:perform_later)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        post job_runs_path, params: { job_id: job.id }

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
