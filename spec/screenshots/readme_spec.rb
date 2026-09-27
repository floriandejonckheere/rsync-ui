# frozen_string_literal: true

# Generates the screenshots used in the README, using the development seeds.
#
#   docker compose exec app bundle exec rspec spec/screenshots
#
RSpec.describe "README screenshots", :screenshots, type: :system do
  # Viewport in CSS pixels, rendered at twice the resolution
  let(:viewport) { { width: 1800, height: 1050, scale_factor: 2 } }

  let(:user) { User.find_by!(email: "admin@example.com") }
  let(:job) { Job.find_by!(name: "Home backup") }

  before do
    travel_to Time.zone.local(2026, 5, 10, 12, 0, 0)

    seed_development_data

    page.driver.browser.page.set_viewport(**viewport)

    sign_in user, scope: :user
  end

  it "takes a screenshot of the dashboard" do
    visit root_path

    expect(save_readme_screenshot("dashboard")).to be_file
  end

  it "takes a screenshot of the activity log" do
    visit job_runs_path

    expect(save_readme_screenshot("activity-log", find("main"), cut_off: all("tbody tr")[6])).to be_file
  end

  it "takes a screenshot of the servers" do
    visit servers_path

    tooltip = find("tr", text: "Encrypted off-site mirrored backup server")
      .find("td:first-child [data-tooltip]")

    expect(save_readme_screenshot("servers", find("main"), hover: tooltip)).to be_file
  end

  it "takes a screenshot of the repositories" do
    visit repositories_path

    tooltip = find("tr", text: "User home directory").find("td:first-child [data-tooltip]")

    expect(save_readme_screenshot("repositories", find("main"), hover: tooltip)).to be_file
  end

  it "takes a screenshot of the jobs" do
    visit jobs_path

    expect(save_readme_screenshot("jobs", find("main"))).to be_file
  end

  it "takes a screenshot of the notifications" do
    visit notifications_path

    expect(save_readme_screenshot("notifications", find("main"))).to be_file
  end

  it "takes a screenshot of the bulk edit" do
    visit bulk_edit_jobs_path

    expect(save_readme_screenshot("jobs-bulk-edit", find("main"), cut_off: all("tbody tr")[11])).to be_file
  end

  it "takes a screenshot of the job" do
    visit edit_job_path(job)

    expect(save_readme_screenshot("job", find("main"), cut_off: card("jobs.form.repositories"))).to be_file
  end

  it "takes a screenshot of the job repositories" do
    visit edit_job_path(job)

    all("input[role=combobox]")[1].set("home")

    listbox = find("[role=listbox]", visible: true)
    listbox.find("[role=option]", text: "Home backup").hover

    expect(save_readme_screenshot("job-repositories", card("jobs.form.repositories"), cut_off: listbox, cut_off_at: 1, cut_off_padding: 24)).to be_file
  end

  it "takes a screenshot of the job notifications" do
    visit edit_job_path(job)

    expect(save_readme_screenshot("job-notifications", card("jobs.form.notifications"))).to be_file
  end

  it "takes a screenshot of the job include/exclude patterns" do
    visit edit_job_path(job)

    expect(save_readme_screenshot("job-include-exclude", open_section("jobs.form.include_exclude_patterns"))).to be_file
  end

  it "takes a screenshot of the job basic options" do
    visit edit_job_path(job)

    expect(save_readme_screenshot("job-basic", open_section("jobs.form.basic_options"))).to be_file
  end

  it "takes a screenshot of the job advanced options" do
    visit edit_job_path(job)

    expect(save_readme_screenshot("job-advanced", open_section("jobs.form.advanced_options"))).to be_file
  end

  it "takes a screenshot of the job custom options" do
    visit edit_job_path(job)

    expect(save_readme_screenshot("job-custom", open_section("jobs.form.custom_options"))).to be_file
  end

  it "takes a screenshot of the job hooks" do
    visit edit_job_path(job)

    # The hook cards all look the same, so cut off halfway the second one
    hooks = open_section("jobs.form.hooks")
    post_hook = hooks.find("h3", text: I18n.t("jobs.form.hooks_post")).ancestor(".border")

    expect(save_readme_screenshot("job-hooks", hooks, cut_off: post_hook)).to be_file
  end

  private

  def seed_development_data
    [Users, Servers, Repositories, Jobs, JobRuns, Notifications, JobNotifications, Hooks].each do |namespace|
      namespace::ImportService.call(path: Rails.root.join("db/seeds/development"))
    end

    # The dashboard orders job runs by creation time, which is the same for all seeded job runs
    JobRun.where.not(started_at: nil).update_all("created_at = started_at") # rubocop:disable Rails/SkipsModelValidations

    mock_resource_usages
    mock_running_job_run
    mock_job_options

    # Job run numbers come from a database sequence, which keeps counting across runs
    JobRun.order(:started_at).each.with_index(1) { |job_run, sequence| job_run.update_columns(sequence:) } # rubocop:disable Rails/SkipsModelValidations
  end

  # Options that are not part of the seeds, to fill the job form
  def mock_job_options
    job.update!(
      opt_include: ["Documents/", "Pictures/"],
      opt_exclude: [".DS_Store", "node_modules/", "*.tmp"],
      opt_arguments: "--bwlimit=5000",
    )
  end

  # Resource usage as if the servers were probed a few minutes ago
  def mock_resource_usages
    {
      "NAS" => { cpu_count: 4, cpu_usage: 23.5, memory_used: 5.4.gigabytes, memory_total: 8.gigabytes, disk_used: 7.1.terabytes, disk_total: 12.terabytes, uptime_seconds: 38.days },
      "Backup" => { cpu_count: 2, cpu_usage: 8.2, memory_used: 1.1.gigabytes, memory_total: 4.gigabytes, disk_used: 14.6.terabytes, disk_total: 16.terabytes, uptime_seconds: 112.days },
      "Mirror" => { cpu_count: 8, cpu_usage: 91.3, memory_used: 13.9.gigabytes, memory_total: 16.gigabytes, disk_used: 2.3.terabytes, disk_total: 8.terabytes, uptime_seconds: 5.days },
    }.each do |name, attributes|
      server = Server.find_by!(name:)
      server.update!(probed_at: 3.minutes.ago, last_seen_at: 3.minutes.ago)

      ResourceUsage.create!(
        server:,
        status: "ok",
        probed_at: 3.minutes.ago,
        load_avg_1: 0.4,
        load_avg_5: 0.3,
        load_avg_15: 0.2,
        **attributes,
      )
    end
  end

  # Job run halfway through the transfer, as if it was being executed by rsync
  def mock_running_job_run
    job = Job.find_by!(name: "Projects backup")

    JobRun.create!(
      job:,
      user:,
      name: job.name,
      description: job.description,
      trigger: "manual",
      status: "running",
      started_at: 4.minutes.ago,
      progress: 44,
      speed: 48.megabytes,
      remaining_time: 5.minutes,
      files_total: 12_840,
      files_transferred: 5_632,
    )
  end

  # Saves the viewport, or the given element with some padding around it (optionally hovering another element), and returns the path
  def save_readme_screenshot(name, element = nil, hover: nil, **)
    path = Rails.root.join("screenshots/#{name}.png")

    # Hide the blinking text cursor in focused inputs
    page.execute_script("document.head.insertAdjacentHTML('beforeend', '<style>* { caret-color: transparent !important }</style>')")

    # Let the chart animations (600ms) finish
    sleep 1

    area = element_area(element, **) if element

    # Hover after resizing the viewport, which would reset the hover state. Show the tooltip on the right, so it stays within the area
    if hover
      hover.execute_script("this.dataset.side = 'right'")
      hover.hover
    end

    page.driver.save_screenshot(path, **(area ? { area: } : {}))

    path
  end

  def card(title)
    find("h2", text: I18n.t(title), exact_text: true)
      .ancestor(".card")
  end

  def open_section(title)
    summary = find("summary", text: I18n.t(title), exact_text: true)
    summary.click

    summary.ancestor("details")
  end

  # Area of the element with some padding around it, optionally cut off at a fraction of the height of another element
  def element_area(element, cut_off: nil, cut_off_at: 0.5, cut_off_padding: 0, padding: 24)
    # Grow the viewport to fit the whole page, so the element can be captured without scrolling
    page.driver.browser.page.set_viewport(**viewport, height: page.evaluate_script("document.documentElement.scrollHeight"))

    x, y, width, height = bounding_rect(element)
    bottom = cut_off ? bounding_rect(cut_off).then { |_, cut_y, _, cut_height| cut_y + (cut_height * cut_off_at) + cut_off_padding } : y + height + padding

    { x: x - padding, y: y - padding, width: width + (2 * padding), height: bottom - (y - padding) }
  end

  def bounding_rect(element)
    element.evaluate_script(<<~JS)
      (({ x, y, width, height }) => [x, y, width, height])(this.getBoundingClientRect())
    JS
  end
end
