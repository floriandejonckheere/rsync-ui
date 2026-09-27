# frozen_string_literal: true

RSpec.describe "Job form implied options" do
  let(:user) { create(:user) }
  let(:job) { create(:job, user:, opt_archive: false, opt_recursive: false, opt_owner: true) }

  before do
    sign_in user, scope: :user

    visit edit_job_path(job)

    find("summary", text: I18n.t("jobs.form.basic_options"))
      .click

    find("summary", text: I18n.t("jobs.form.advanced_options"))
      .click
  end

  it "enables and locks the options implied by --archive" do
    check "job_opt_archive"

    Job::IMPLIED_OPTIONS[:opt_archive].each do |option|
      expect(page).to have_field("job_#{option}", checked: true, disabled: true)
    end
  end

  it "restores the implied options when disabling --archive" do
    check "job_opt_archive"
    uncheck "job_opt_archive"

    expect(page).to have_field("job_opt_recursive", checked: false, disabled: false)
    expect(page).to have_field("job_opt_owner", checked: true, disabled: false)
  end
end
