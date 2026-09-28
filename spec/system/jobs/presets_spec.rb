# frozen_string_literal: true

RSpec.describe "Job form presets" do
  let(:user) { create(:user) }
  let(:job) { create(:job, user:, opt_archive: false, opt_compress: true, opt_ignore_existing: true, opt_arguments: "--bwlimit=1000") }

  before do
    sign_in user, scope: :user

    visit edit_job_path(job)

    find("summary", text: I18n.t("jobs.form.basic_options"))
      .click

    find("summary", text: I18n.t("jobs.form.advanced_options"))
      .click

    find("summary", text: I18n.t("jobs.form.custom_options"))
      .click
  end

  it "overwrites the options after confirmation" do
    select JobPreset.find("borg").name, from: "job-preset"

    within("#turbo-confirm-dialog") do
      expect(page).to have_text(I18n.t("jobs.form.preset_confirm"))

      click_on I18n.t("jobs.form.preset_confirm_button")
    end

    expect(page).to have_text(JobPreset.find("borg").description)

    expect(page).to have_field("job_opt_archive", checked: true)
    expect(page).to have_field("job_opt_perms", checked: true, disabled: true)
    expect(page).to have_field("job_opt_delete", checked: true)
    expect(page).to have_field("job_opt_delete_after", checked: true)
    expect(page).to have_field("job_opt_delete_before", checked: false, disabled: true)
    expect(page).to have_field("job_opt_numeric_ids", checked: true)
    expect(page).to have_field("job_opt_compress", checked: false)
    expect(page).to have_field("job_opt_ignore_existing", checked: false)
    expect(page).to have_field("job_opt_arguments", with: "--whole-file --sparse")

    within("turbo-frame#command-preview") do
      expect(page).to have_text("--numeric-ids")
    end

    find("button[form='job-form']").click

    expect(page).to have_current_path(jobs_path)
    expect(job.reload).to have_attributes(opt_archive: true, opt_delete_after: true, opt_compress: false, opt_ignore_existing: false, opt_arguments: "--whole-file --sparse")
  end

  it "only enables the options of an additive preset" do
    select JobPreset.find("trial_run").name, from: "job-preset"

    within("#turbo-confirm-dialog") do
      expect(page).to have_text(I18n.t("jobs.form.preset_confirm_additive"))

      click_on I18n.t("jobs.form.preset_confirm_button")
    end

    expect(page).to have_field("job_opt_dry_run", checked: true)
    expect(page).to have_field("job_opt_itemize_changes", checked: true)
    expect(page).to have_field("job_opt_compress", checked: true)
    expect(page).to have_field("job_opt_ignore_existing", checked: true)
    expect(page).to have_field("job_opt_arguments", with: "--bwlimit=1000")
  end

  it "keeps the options when cancelled" do
    select JobPreset.find("borg").name, from: "job-preset"

    within("#turbo-confirm-dialog") do
      click_on I18n.t("confirm_dialog.cancel")
    end

    expect(page).to have_select("job-preset", selected: I18n.t("jobs.form.preset_placeholder"))
    expect(page).to have_field("job_opt_archive", checked: false)
    expect(page).to have_field("job_opt_compress", checked: true)
    expect(page).to have_field("job_opt_arguments", with: "--bwlimit=1000")
  end
end
