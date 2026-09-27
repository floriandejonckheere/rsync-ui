# frozen_string_literal: true

RSpec.describe "Job form delete options" do
  let(:user) { create(:user) }
  let(:job) { create(:job, user:) }

  before do
    sign_in user, scope: :user

    visit edit_job_path(job)

    find("summary", text: I18n.t("jobs.form.basic_options"))
      .click
  end

  it "enables --delete when enabling a delete timing option" do
    check "job_opt_delete_after"

    expect(page).to have_checked_field("job_opt_delete")
  end

  it "enables --delete when enabling --delete-excluded" do
    check "job_opt_delete_excluded"

    expect(page).to have_checked_field("job_opt_delete")
  end

  it "disables the other delete timing options when enabling one" do
    check "job_opt_delete_after"

    expect(page).to have_field("job_opt_delete_before", checked: false, disabled: true)
    expect(page).to have_field("job_opt_delete_during", checked: false, disabled: true)
    expect(page).to have_field("job_opt_delete_delay", checked: false, disabled: true)
  end

  it "disables the specific delete options when disabling --delete" do
    check "job_opt_delete_after"
    check "job_opt_delete_excluded"

    uncheck "job_opt_delete"

    expect(page).to have_field("job_opt_delete_after", checked: false)
    expect(page).to have_field("job_opt_delete_excluded", checked: false)
    expect(page).to have_field("job_opt_delete_before", checked: false, disabled: false)
  end
end
