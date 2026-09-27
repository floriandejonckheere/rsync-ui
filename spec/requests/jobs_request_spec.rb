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

      context "when jobs have categories" do
        it "renders uncategorized jobs before the categorized ones" do
          categorized_job = create(:job, user:, name: "Alpha job", category_name: "Backups")
          uncategorized_job = create(:job, user:, name: "Zebra job")

          get jobs_path

          expect(response.body.index(uncategorized_job.name)).to be < response.body.index(categorized_job.name)
        end

        it "groups the categorized jobs per category" do
          backups_job = create(:job, user:, name: "Zebra job", category_name: "Backups")
          mirrors_job = create(:job, user:, name: "Alpha job", category_name: "Mirrors")

          get jobs_path

          expect(response.body).to include("Backups", "Mirrors")
          expect(response.body.index(backups_job.name)).to be < response.body.index(mirrors_job.name)
        end

        it "renders an inline form to rename the category" do
          job = create(:job, user:, category_name: "Backups")

          get jobs_path

          expect(response.body).to include(I18n.t("categories.heading.edit"), category_path(job.category))
        end

        it "renders an uncategorized heading when categories are present" do
          create(:job, user:, name: "Nightly backup")
          create(:job, user:, name: "Offsite mirror", category_name: "Mirrors")

          get jobs_path

          expect(response.body).to include(I18n.t("jobs.index.uncategorized"))
        end

        it "does not render an uncategorized heading when no job has a category" do
          create(:job, user:, name: "Nightly backup")

          get jobs_path

          expect(response.body).not_to include(I18n.t("jobs.index.uncategorized"))
        end

        it "sorts the jobs within each category" do
          create(:job, user:, name: "Beta job", category_name: "Backups")
          create(:job, user:, name: "Alpha job", category_name: "Backups")

          get jobs_path, params: { sort: "name", direction: "desc" }

          expect(response.body.index("Beta job")).to be < response.body.index("Alpha job")
        end

        it "does not render categories without matching jobs when searching" do
          create(:job, user:, name: "Nightly backup", category_name: "Backups")
          create(:job, user:, name: "Offsite mirror", category_name: "Mirrors")

          get jobs_path, params: { query: "Nightly" }

          expect(response.body).to include("Backups")
          expect(response.body).not_to include("Mirrors")
        end
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

      it "saves the category" do
        post jobs_path, params: { job: valid_params[:job].merge(category_name: "Backups") }

        expect(user.jobs.last.category_name).to eq("Backups")
      end

      it "saves opt_include patterns" do
        post jobs_path, params: {
          job: valid_params[:job].merge(opt_include: ["*.log", "docs/"], opt_exclude: []),
        }

        expect(user.jobs.last.opt_include).to eq(["*.log", "docs/"])
      end

      it "saves opt_exclude patterns" do
        post jobs_path, params: {
          job: valid_params[:job].merge(opt_include: [], opt_exclude: ["*.tmp"]),
        }

        expect(user.jobs.last.opt_exclude).to eq ["*.tmp"]
      end

      it "saves delete timing options" do
        post jobs_path, params: {
          job: valid_params[:job].merge(
            opt_delete: true,
            opt_delete_delay: true,
            opt_delete_excluded: true,
          ),
        }

        job = user.jobs.last
        expect(job.opt_delete).to be(true)
        expect(job.opt_delete_delay).to be(true)
        expect(job.opt_delete_excluded).to be(true)
      end

      it "does not save multiple delete timing options" do
        expect do
          post jobs_path, params: {
            job: valid_params[:job].merge(
              opt_delete: true,
              opt_delete_before: true,
              opt_delete_after: true,
            ),
          }
        end.not_to change(Job, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "does not save delete options without opt_delete" do
        expect do
          post jobs_path, params: {
            job: valid_params[:job].merge(opt_delete: false, opt_delete_after: true),
          }
        end.not_to change(Job, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "saves empty arrays when blank pattern values are submitted" do
        post jobs_path, params: {
          job: valid_params[:job].merge(opt_include: ["", ""], opt_exclude: [""]),
        }

        job = user.jobs.last
        expect(job.opt_include).to be_empty
        expect(job.opt_exclude).to be_empty
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

  describe "GET /jobs/:id/duplicate" do
    let(:job) { create(:job, user:) }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "renders the duplicate page" do
        get duplicate_job_path(job)

        expect(response).to have_http_status(:ok)

        expect(response.body).to include "#{job.name} (copy)"
      end
    end

    context "when job belongs to another user" do
      let(:job) { create(:job, user: other_user) }

      before { sign_in user, scope: :user }

      it "returns forbidden" do
        get duplicate_job_path(job)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get duplicate_job_path(job)

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

      it "updates the ping settings" do
        patch job_path(job), params: { job: { ping: true, ping_action: "cancel" } }

        expect(job.reload).to be_ping
        expect(job).to be_ping_cancel
      end

      it "displays success message" do
        patch job_path(job), params: update_params

        follow_redirect!

        expect(response.body).to include(I18n.t("jobs.update.success"))
      end

      it "updates the category" do
        patch job_path(job), params: { job: { category_name: "Backups" } }

        expect(job.reload.category_name).to eq("Backups")
      end

      it "clears the category when it is submitted blank" do
        job.update!(category_name: "Backups")

        patch job_path(job), params: { job: { category_name: "" } }

        expect(job.reload.category).to be_nil
      end

      it "updates the delete timing options" do
        patch job_path(job), params: {
          job: {
            opt_delete: true,
            opt_delete_after: true,
          },
        }

        job.reload
        expect(job.opt_delete).to be(true)
        expect(job.opt_delete_after).to be(true)
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

  describe "GET /jobs/bulk_edit" do
    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "renders the jobs as columns and the options as rows" do
        job = create(:job, user:, name: "Nightly backup")

        get bulk_edit_jobs_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(job.name, I18n.t("jobs.form.opt_archive.description"), "jobs[#{job.id}][opt_archive]")
      end

      it "groups the jobs per category" do
        create(:job, user:, name: "Nightly backup", category_name: "Backups")
        create(:job, user:, name: "Offsite mirror")

        get bulk_edit_jobs_path

        expect(response.body).to include("Backups", I18n.t("jobs.index.uncategorized"))
        expect(response.body.index("Offsite mirror")).to be < response.body.index("Nightly backup")
      end

      it "does not render jobs of other users" do
        job = create(:job, user: other_user, name: "Foreign job")

        get bulk_edit_jobs_path

        expect(response.body).not_to include(job.name)
      end

      it "renders an empty state when there are no jobs" do
        get bulk_edit_jobs_path

        expect(response.body).to include(I18n.t("jobs.index.empty"))
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get bulk_edit_jobs_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /jobs/bulk_update" do
    let!(:job) { create(:job, user:, opt_compress: false, opt_checksum: false) }
    let!(:other_job) { create(:job, user:, name: "Offsite mirror", opt_compress: true) }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "updates the options of every job" do
        patch bulk_update_jobs_path, params: {
          jobs: {
            job.id => { opt_compress: "1", opt_checksum: "1" },
            other_job.id => { opt_compress: "0" },
          },
        }

        expect(job.reload).to have_attributes(opt_compress: true, opt_checksum: true)
        expect(other_job.reload.opt_compress).to be(false)
        expect(response).to redirect_to(jobs_path)
      end

      it "only saves the jobs that changed" do
        expect do
          patch bulk_update_jobs_path, params: {
            jobs: {
              job.id => { opt_compress: "1" },
              other_job.id => { opt_compress: "1" },
            },
          }
        end.not_to(change { other_job.reload.updated_at })

        follow_redirect!

        expect(response.body).to include(I18n.t("jobs.bulk_update.success", count: 1))
      end

      it "leaves options that are not submitted untouched" do
        job.update!(opt_recursive: false)

        patch bulk_update_jobs_path, params: { jobs: { job.id => { opt_archive: "1" } } }

        expect(job.reload).to have_attributes(opt_archive: true, opt_recursive: false)
      end

      it "does not update non-option attributes" do
        patch bulk_update_jobs_path, params: { jobs: { job.id => { name: "Hacked", opt_arguments: "--rsh=evil" } } }

        expect(job.reload).to have_attributes(name: job.name, opt_arguments: job.opt_arguments)
      end

      it "does not update jobs of other users" do
        foreign_job = create(:job, user: other_user, opt_compress: false)

        patch bulk_update_jobs_path, params: { jobs: { foreign_job.id => { opt_compress: "1" } } }

        expect(foreign_job.reload.opt_compress).to be(false)
      end

      it "ignores malformed parameters" do
        patch bulk_update_jobs_path, params: { jobs: { job.id => "1" } }

        expect(response).to redirect_to(jobs_path)
      end

      context "when a job is invalid" do
        let(:params) do
          {
            jobs: {
              job.id => { opt_compress: "1" },
              other_job.id => { opt_delete: "1", opt_delete_before: "1", opt_delete_after: "1" },
            },
          }
        end

        it "does not update any job" do
          patch(bulk_update_jobs_path, params:)

          expect(job.reload.opt_compress).to be(false)
          expect(other_job.reload.opt_delete).to be(false)
        end

        it "re-renders the page with the errors" do
          patch(bulk_update_jobs_path, params:)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include(other_job.name, I18n.t("activerecord.errors.models.job.attributes.base.multiple_delete_timings"))
        end

        it "keeps the submitted values while exposing the saved values" do
          patch(bulk_update_jobs_path, params:)

          checkbox = response.parsed_body.at_css("input[type='checkbox'][name='jobs[#{job.id}][opt_compress]']")

          expect(checkbox.to_h).to include("checked" => "checked", "data-saved" => "false")
        end
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        patch bulk_update_jobs_path, params: { jobs: { job.id => { opt_compress: "1" } } }

        expect(response).to redirect_to(new_user_session_path)
        expect(job.reload.opt_compress).to be(false)
      end
    end
  end

  describe "POST /jobs/preview" do
    let(:source_repository) { create(:repository, user:) }
    let(:destination_repository) { create(:repository, user:) }
    let(:valid_params) do
      {
        job: {
          name: "Preview Job",
          source_repository_id: source_repository.id,
          destination_repository_id: destination_repository.id,
          opt_archive: true,
          opt_dry_run: true,
        },
      }
    end

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "returns the command preview" do
        post preview_jobs_path, params: valid_params

        expect(response).to have_http_status(:ok)

        expect(response.body).to include("rsync \\")
        expect(response.body).to include("--archive")
        expect(response.body).to include("--dry-run")
      end

      it "returns the command preview with delete timing options" do
        post preview_jobs_path, params: {
          job: valid_params[:job].merge(opt_delete: true, opt_delete_delay: true),
        }

        expect(response.body).to include("--delete")
        expect(response.body).to include("--delete-delay")
      end

      it "includes source and destination placeholders when repositories are absent" do
        post preview_jobs_path, params: { job: { name: "No repos" } }

        expect(response.body).to include("&lt;source&gt;")
        expect(response.body).to include("&lt;destination&gt;")
      end

      it "does not persist a job" do
        expect { post preview_jobs_path, params: valid_params }
          .not_to change(Job, :count)
      end

      it "does not raise when nested attributes reference existing records" do
        job = create(:job, user:, source_repository:, destination_repository:)
        notification = create(:job_notification, job:)
        hook = create(:hook, job:)

        preview_params = valid_params.deep_merge(
          job: {
            job_notifications_attributes: { "0" => { id: notification.id, enabled: true } },
            hooks_attributes: { "0" => { id: hook.id, enabled: true } },
          },
        )

        post preview_jobs_path, params: preview_params

        expect(response).to have_http_status(:ok)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        post preview_jobs_path, params: valid_params

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /jobs with notifications" do
    let(:user) { create(:user) }
    let(:source) { create(:repository, :local, user:) }
    let(:destination) { create(:repository, :local, user:, read_only: false) }
    let(:notification) { create(:notification, user:) }

    before { sign_in user, scope: :user }

    it "creates job_notifications via nested attributes" do
      params = {
        job: {
          name: "With notifs",
          source_repository_id: source.id,
          destination_repository_id: destination.id,
          job_notifications_attributes: {
            "0" => {
              notification_id: notification.id,
              enabled: "1",
              on_start: "1",
              on_success: "1",
              on_failure: "0",
            },
          },
        },
      }

      expect { post jobs_path, params: }
        .to change(JobNotification, :count).by(1)
    end
  end
end
