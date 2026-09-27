# frozen_string_literal: true

RSpec.describe "Bulk edit jobs" do
  let(:user) { create(:user) }
  let!(:job) { create(:job, user:, name: "Nightly backup", opt_compress: false, opt_archive: false, opt_recursive: false) }
  let!(:other_job) { create(:job, user:, name: "Offsite mirror", opt_compress: false) }

  before do
    sign_in user, scope: :user

    visit bulk_edit_jobs_path
  end

  it "toggles the switch when clicking its cell" do
    find_field(option(job, :opt_compress))
      .ancestor("td")
      .click(x: 4, y: 4)

    expect(page).to have_checked_field(option(job, :opt_compress))
  end

  it "applies the implied options per job" do
    check option(job, :opt_archive)

    expect(page).to have_field(option(job, :opt_recursive), checked: true, disabled: true)
    expect(page).to have_field(option(other_job, :opt_recursive), disabled: false)
  end

  it "applies the delete options per job" do
    check option(job, :opt_delete_after)

    expect(page).to have_checked_field(option(job, :opt_delete))
    expect(page).to have_field(option(job, :opt_delete_before), disabled: true)
    expect(page).to have_field(option(other_job, :opt_delete), checked: false)

    uncheck option(job, :opt_delete)

    expect(page).to have_field(option(job, :opt_delete_after), checked: false)
  end

  it "updates the modified jobs" do
    check option(job, :opt_compress)

    save

    expect(job.reload.opt_compress).to be(true)
  end

  it "does not submit the unmodified jobs" do
    expect { save }.not_to(change { other_job.reload.updated_at })
  end

  it "does not update the options locked by an implying option" do
    check option(job, :opt_archive)

    save

    expect(job.reload).to have_attributes(opt_archive: true, opt_recursive: false)
  end

  it "resubmits the modified jobs after a failed submit" do
    check option(job, :opt_compress)

    # Force an invalid job by enabling two delete timings behind the controller's back
    page.execute_script(<<~JS)
      ["opt_delete", "opt_delete_before", "opt_delete_after"].forEach(name => {
        const option = document.getElementById("jobs_#{other_job.id}_" + name)
        option.disabled = false
        option.checked = true
      })
    JS

    find("button[form='bulk-edit-form']")
      .click

    expect(page).to have_text(I18n.t("activerecord.errors.models.job.attributes.base.multiple_delete_timings"))

    uncheck option(other_job, :opt_delete)

    save

    expect(job.reload.opt_compress).to be(true)
    expect(other_job.reload.opt_delete).to be(false)
  end

  def option(job, option)
    "jobs_#{job.id}_#{option}"
  end

  def save
    find("button[form='bulk-edit-form']")
      .click

    expect(page).to have_current_path(jobs_path)
  end
end
