# frozen_string_literal: true

RSpec.describe "Dashboard" do
  let(:user) { create(:user) }

  before { sign_in user, scope: :user }

  describe "GET /" do
    it "renders successfully" do
      get root_path

      expect(response).to have_http_status(:ok)
    end

    context "when notifications are enabled" do
      with_configuration "notifications" => true

      it "shows the notifications menu item" do
        get root_path

        expect(response.body).to include I18n.t("notifications.title")
      end
    end

    context "when notifications are disabled" do
      with_configuration "notifications" => false

      it "hides the notifications menu item" do
        get root_path

        expect(response.body).not_to include I18n.t("notifications.title")
      end
    end

    context "with no job runs in the past 24 hours" do
      it "shows Unknown status" do
        get root_path

        expect(response.body).to include I18n.t("dashboard.status.unknown")
      end
    end

    context "with only completed job runs in the past 24 hours" do
      it "shows Healthy status" do
        job = create(:job, user:)
        create(:job_run, :completed, job:, user:, started_at: 1.hour.ago)

        get root_path

        expect(response.body).to include I18n.t("dashboard.status.healthy")
      end
    end

    context "with a failed job run in the past 24 hours" do
      it "shows Degraded status" do
        job = create(:job, user:)
        create(:job_run, :failed, job:, user:, started_at: 1.hour.ago)

        get root_path

        expect(response.body).to include I18n.t("dashboard.status.degraded")
      end
    end

    context "with no job runs" do
      it "shows no runs yet message on last job run card" do
        get root_path

        expect(response.body).to include I18n.t("dashboard.last_job_run.no_runs")
      end
    end

    context "with a completed job run" do
      it "shows the job name on the last job run card" do
        job = create(:job, user:, name: "Backup Photos")
        create(:job_run, :completed, job:, user:, started_at: 2.hours.ago)

        get root_path

        expect(response.body).to include "Backup Photos"
      end
    end

    context "with no scheduled jobs" do
      it "shows no scheduled jobs message" do
        get root_path

        expect(response.body).to include I18n.t("dashboard.next_job.no_jobs")
      end
    end

    context "with an enabled scheduled job" do
      it "shows the job name on the next job card" do
        source      = create(:repository, :local, user:)
        destination = create(:repository, :remote, user:)
        create(:job, user:, name: "Nightly Sync", schedule: "0 2 * * *",
                     enabled: true, source_repository: source, destination_repository: destination,)

        get root_path

        expect(response.body).to include "Nightly Sync"
      end
    end

    it "shows repository counts" do
      create(:repository, :local, user:)
      create(:repository, :local, user:)
      create(:repository, :remote, user:)

      get root_path

      expect(response.body).to include I18n.t("dashboard.repositories.title")
    end

    it "shows storage card" do
      get root_path

      expect(response.body).to include I18n.t("dashboard.storage.title")
    end
  end
end
