# Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to configure Apprise-based notification destinations and attach them to jobs so messages are sent on lifecycle events (start / success / failure).

**Architecture:** A user-scoped `Notification` model stores Apprise URLs (encrypted at rest). A `JobNotification` join model links notifications to jobs and configures per-event flags. `JobRuns::ExecuteService` enqueues `Notifications::SendJob` per (notification × event), which renders an ERB body and shells out to the Apprise CLI installed in the Docker image. A `notifications` boolean configuration (default `true`) gates the entire feature.

**Tech Stack:** Rails 8.0, PostgreSQL 18, ActiveRecord encryption, ActionPolicy, SolidQueue, ViewComponent + ERB + Tailwind/Basecoat, RSpec + FactoryBot + Shoulda Matchers, Apprise CLI (Python) installed via pip in Alpine Docker image.

**Spec:** [docs/superpowers/specs/2026-05-01-notifications-design.md](../specs/2026-05-01-notifications-design.md)

---

## Conventions for every task

- All Ruby files start with `# frozen_string_literal: true`.
- After modifying any `db/migrate/*` file, run `docker compose exec app bundle exec annotaterb models`.
- After modifying `config/routes.rb`, run `docker compose exec app bundle exec annotaterb routes`.
- After modifying `config/locales/*.yml`, run `docker compose exec app bundle exec i18n-tasks normalize`.
- After modifying any `*.html.erb`, run `docker compose exec app yarn herb:format`.
- Each task ends with running the relevant tests and a single commit (per CLAUDE.md).
- Use `docker compose exec app` for all rake/rails/rspec/rubocop/yarn commands.
- The current branch is `notifications` (already created earlier in the session).

---

## File Structure

**Created files**

- `requirements.txt`
- `db/migrate/<timestamp>_create_notifications.rb`
- `db/migrate/<timestamp>_create_job_notifications.rb`
- `app/models/notification.rb`
- `app/models/job_notification.rb`
- `spec/factories/notifications.rb`
- `spec/factories/job_notifications.rb`
- `spec/models/notification_spec.rb`
- `spec/models/job_notification_spec.rb`
- `app/policies/notification_policy.rb`
- `spec/policies/notification_policy_spec.rb`
- `app/controllers/notifications_controller.rb`
- `spec/requests/notifications_request_spec.rb`
- `app/views/notifications/index.html.erb`
- `app/views/notifications/_notification.html.erb`
- `app/views/notifications/_form.html.erb`
- `app/views/notifications/new.html.erb`
- `app/views/notifications/edit.html.erb`
- `app/views/notifications/_start.text.erb`
- `app/views/notifications/_success.text.erb`
- `app/views/notifications/_failure.text.erb`
- `app/services/notifications/render_service.rb`
- `app/services/notifications/send_service.rb`
- `app/services/notifications/test_service.rb`
- `app/jobs/notifications/send_job.rb`
- `spec/services/notifications/render_service_spec.rb`
- `spec/services/notifications/send_service_spec.rb`
- `spec/services/notifications/test_service_spec.rb`
- `spec/jobs/notifications/send_job_spec.rb`
- `config/locales/notifications.en.yml`

**Modified files**

- `Dockerfile`, `Dockerfile.prod` (Apprise install)
- `.github/dependabot.yml` (pip ecosystem)
- `config/configurations.yml` (`notifications` key)
- `config/locales/configurations.yml` (translation for new key)
- `config/routes.rb` (notifications resources)
- `app/models/user.rb` (`has_many :notifications`)
- `app/models/job.rb` (join association + nested attrs)
- `app/services/jobs/execute_service.rb` (enqueue hooks)
- `app/controllers/jobs_controller.rb` (strong params)
- `app/views/jobs/_form.html.erb` (notifications card)
- `app/views/layouts/application.html.erb` (menu entry)
- `config/locales/en.yml` (nav title only — full nested keys live in `notifications.en.yml`)
- `docs/PROJECT.md` (move/check off completed items)
- `docs/features/NOTIFICATIONS.md` (check off boxes)

---

## Task 1: Install Apprise in Docker images

**Files:**
- Create: `requirements.txt`
- Modify: `Dockerfile`
- Modify: `Dockerfile.prod`

- [ ] **Step 1: Create `requirements.txt`**

```
apprise==1.10.0
```

(Use the latest published version on pypi.org; bump if a newer one exists at the time of execution.)

- [ ] **Step 2: Modify `Dockerfile`**

In the `RUNTIME_DEPS` line near the top, append `python3 py3-pip`:

```dockerfile
ENV RUNTIME_DEPS postgresql gmp vips openssh rsync python3 py3-pip
```

After the existing `RUN apk add --no-cache $BUILD_DEPS $RUNTIME_DEPS` line, add:

```dockerfile
# Install Apprise (notification dispatcher)
ADD requirements.txt $APP_HOME
RUN python3 -m venv /opt/apprise-venv \
 && /opt/apprise-venv/bin/pip install --no-cache-dir -r requirements.txt \
 && /opt/apprise-venv/bin/apprise --version
ENV PATH="/opt/apprise-venv/bin:$PATH"
```

- [ ] **Step 3: Apply identical changes to `Dockerfile.prod`**

Same `RUNTIME_DEPS` extension, same Apprise install block, same `ENV PATH`. Place the block at a position equivalent to the dev image (after system deps install).

- [ ] **Step 4: Build to verify**

Run: `docker compose build app`
Expected: build completes; the `apprise --version` line in the build output prints a version string.

- [ ] **Step 5: Commit**

```bash
git add requirements.txt Dockerfile Dockerfile.prod
git commit -m "Add apprise dependency"
```

---

## Task 2: Add pip ecosystem to dependabot

**Files:**
- Modify: `.github/dependabot.yml`

- [ ] **Step 1: Append a pip block**

After the last existing `update:` entry, add:

```yaml
  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
```

- [ ] **Step 2: Validate YAML**

Run: `docker compose exec app ruby -ryaml -e 'YAML.load_file(".github/dependabot.yml")'`
Expected: no output, exit 0.

- [ ] **Step 3: Commit**

```bash
git add .github/dependabot.yml
git commit -m "Add pip ecosystem to dependabot"
```

---

## Task 3: Create `notifications` table + model + factory + spec

**Files:**
- Create: `db/migrate/<timestamp>_create_notifications.rb`
- Create: `app/models/notification.rb`
- Create: `spec/factories/notifications.rb`
- Create: `spec/models/notification_spec.rb`
- Modify: `app/models/user.rb`

- [ ] **Step 1: Generate migration**

Run: `docker compose exec app bundle exec rails generate migration CreateNotifications`

- [ ] **Step 2: Fill in migration**

Replace the generated file body with:

```ruby
# frozen_string_literal: true

class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.text :description
      t.text :url, null: false
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end
  end
end
```

- [ ] **Step 3: Ask the user to confirm before running the migration, then run it**

Per CLAUDE.md, prompt for confirmation. Then run:

`docker compose exec app bundle exec rails db:migrate`

- [ ] **Step 4: Create `app/models/notification.rb`**

```ruby
# frozen_string_literal: true

class Notification < ApplicationRecord
  encrypts :url

  belongs_to :user

  has_many :job_notifications, dependent: :destroy
  has_many :jobs, through: :job_notifications

  validates :name, presence: true
  validates :url, presence: true
  validate :url_has_scheme

  private

  def url_has_scheme
    return if url.blank?

    parsed = URI.parse(url)
    errors.add(:url, :invalid) if parsed.scheme.blank?
  rescue URI::InvalidURIError
    errors.add(:url, :invalid)
  end
end
```

- [ ] **Step 5: Add `has_many :notifications` to `User`**

In `app/models/user.rb`, add inside the class body (alongside other `has_many` declarations):

```ruby
has_many :notifications, dependent: :destroy
```

- [ ] **Step 6: Create factory `spec/factories/notifications.rb`**

```ruby
# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    user

    name { FFaker::Internet.domain_word.capitalize }
    description { nil }
    url { "json://#{FFaker::Internet.domain_name}/webhook" }
    enabled { true }
  end
end
```

- [ ] **Step 7: Create `spec/models/notification_spec.rb`**

```ruby
# frozen_string_literal: true

RSpec.describe Notification do
  subject(:notification) { build(:notification) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:job_notifications).dependent(:destroy) }
    it { is_expected.to have_many(:jobs).through(:job_notifications) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:url) }

    context "when url has no scheme" do
      subject(:notification) { build(:notification, url: "no-scheme") }

      it { is_expected.not_to be_valid }
    end

    context "when url is malformed" do
      subject(:notification) { build(:notification, url: "ht!tp://[bad") }

      it { is_expected.not_to be_valid }
    end
  end

  describe "encryption" do
    it "encrypts the url" do
      notification = create(:notification, url: "json://example.com/hook")

      raw = ActiveRecord::Base.connection.execute(
        "SELECT url FROM notifications WHERE id = '#{notification.id}'",
      ).first["url"]

      expect(raw).not_to include("example.com")
      expect(notification.reload.url).to eq("json://example.com/hook")
    end
  end
end
```

- [ ] **Step 8: Annotate models**

Run: `docker compose exec app bundle exec annotaterb models`

- [ ] **Step 9: Run tests**

Run: `docker compose exec app bundle exec rspec spec/models/notification_spec.rb`
Expected: all examples pass.

- [ ] **Step 10: Run rubocop**

Run: `docker compose exec app bundle exec rubocop app/models/notification.rb app/models/user.rb spec/models/notification_spec.rb spec/factories/notifications.rb db/migrate`

- [ ] **Step 11: Commit**

```bash
git add db/migrate db/schema.rb app/models/notification.rb app/models/user.rb \
        spec/factories/notifications.rb spec/models/notification_spec.rb
git commit -m "Create notifications table"
```

---

## Task 4: Create `job_notifications` join table + model + factory + spec

**Files:**
- Create: `db/migrate/<timestamp>_create_job_notifications.rb`
- Create: `app/models/job_notification.rb`
- Create: `spec/factories/job_notifications.rb`
- Create: `spec/models/job_notification_spec.rb`
- Modify: `app/models/job.rb`

- [ ] **Step 1: Generate migration**

Run: `docker compose exec app bundle exec rails generate migration CreateJobNotifications`

- [ ] **Step 2: Fill in migration**

```ruby
# frozen_string_literal: true

class CreateJobNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :job_notifications, id: :uuid do |t|
      t.references :job, type: :uuid, null: false, foreign_key: true, index: true
      t.references :notification, type: :uuid, null: false, foreign_key: true, index: true

      t.boolean :enabled, null: false, default: true
      t.boolean :on_start, null: false, default: false
      t.boolean :on_success, null: false, default: true
      t.boolean :on_failure, null: false, default: true

      t.timestamps

      t.index [:job_id, :notification_id], unique: true
    end
  end
end
```

- [ ] **Step 3: Confirm and run migration**

Prompt user, then run: `docker compose exec app bundle exec rails db:migrate`

- [ ] **Step 4: Create `app/models/job_notification.rb`**

```ruby
# frozen_string_literal: true

class JobNotification < ApplicationRecord
  belongs_to :job
  belongs_to :notification

  validates :notification_id, uniqueness: { scope: :job_id }
end
```

- [ ] **Step 5: Update `app/models/job.rb`**

Add inside the class body, after the existing `has_many :job_runs`:

```ruby
has_many :job_notifications, dependent: :destroy
has_many :notifications, through: :job_notifications

accepts_nested_attributes_for :job_notifications, allow_destroy: true
```

- [ ] **Step 6: Create factory `spec/factories/job_notifications.rb`**

```ruby
# frozen_string_literal: true

FactoryBot.define do
  factory :job_notification do
    job
    notification
  end
end
```

- [ ] **Step 7: Create `spec/models/job_notification_spec.rb`**

```ruby
# frozen_string_literal: true

RSpec.describe JobNotification do
  describe "associations" do
    it { is_expected.to belong_to(:job) }
    it { is_expected.to belong_to(:notification) }
  end

  describe "defaults" do
    subject(:job_notification) { create(:job_notification) }

    it "defaults enabled to true" do
      expect(job_notification).to be_enabled
    end

    it "defaults on_start to false" do
      expect(job_notification).not_to be_on_start
    end

    it "defaults on_success to true" do
      expect(job_notification).to be_on_success
    end

    it "defaults on_failure to true" do
      expect(job_notification).to be_on_failure
    end
  end

  describe "uniqueness" do
    it "rejects duplicate (job, notification) pairs" do
      existing = create(:job_notification)
      duplicate = build(:job_notification, job: existing.job, notification: existing.notification)

      expect(duplicate).not_to be_valid
    end
  end
end
```

- [ ] **Step 8: Annotate**

Run: `docker compose exec app bundle exec annotaterb models`

- [ ] **Step 9: Run tests**

Run: `docker compose exec app bundle exec rspec spec/models/job_notification_spec.rb spec/models/job_spec.rb`
Expected: all pass.

- [ ] **Step 10: Run rubocop**

Run: `docker compose exec app bundle exec rubocop app/models/job_notification.rb app/models/job.rb spec/models/job_notification_spec.rb spec/factories/job_notifications.rb db/migrate`

- [ ] **Step 11: Commit**

```bash
git add db/migrate db/schema.rb app/models/job_notification.rb app/models/job.rb \
        spec/factories/job_notifications.rb spec/models/job_notification_spec.rb
git commit -m "Create job_notifications join table"
```

---

## Task 5: Add `notifications` configuration entry

**Files:**
- Modify: `config/configurations.yml`
- Modify: `config/locales/configurations.yml`

- [ ] **Step 1: Append to `config/configurations.yml`**

```yaml
- key: notifications
  type: boolean
  category: notifications
  default: true
```

- [ ] **Step 2: Add translations to `config/locales/configurations.yml`**

Add a new `notifications` key under `categories:`:

```yaml
      notifications:
        description: Settings for notifications sent on job lifecycle events
        title: Notifications
```

And under `keys:`:

```yaml
      notifications:
        description: Enable or disable user notifications on job start, success, and failure
```

- [ ] **Step 3: Normalize i18n**

Run: `docker compose exec app bundle exec i18n-tasks normalize`

- [ ] **Step 4: Verify config loads**

Run: `docker compose exec app bundle exec rails runner 'puts Configuration.get("notifications").inspect'`
Expected: `true`.

- [ ] **Step 5: Commit**

```bash
git add config/configurations.yml config/locales/configurations.yml
git commit -m "Add notifications configuration key"
```

---

## Task 6: Notification policy + spec

**Files:**
- Create: `app/policies/notification_policy.rb`
- Create: `spec/policies/notification_policy_spec.rb`

- [ ] **Step 1: Write spec first**

`spec/policies/notification_policy_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe NotificationPolicy do
  subject(:policy) { described_class.new(record, user:) }

  let(:owner)      { build(:user) }
  let(:other_user) { build(:user) }
  let(:admin)      { build(:user, :admin) }
  let(:record)     { build(:notification, user: owner) }
  let(:user)       { owner }

  describe "#index?" do
    it { is_expected.to be_index }
  end

  describe "#show?" do
    it { is_expected.to be_show }

    context "when user is another user" do
      let(:user) { other_user }
      it { is_expected.not_to be_show }
    end

    context "when user is admin" do
      let(:user) { admin }
      it { is_expected.to be_show }
    end
  end

  describe "#create?" do
    it { is_expected.to be_create }

    context "when user is another user" do
      let(:user) { other_user }
      it { is_expected.not_to be_create }
    end
  end

  describe "#update?" do
    it { is_expected.to be_update }

    context "when user is another user" do
      let(:user) { other_user }
      it { is_expected.not_to be_update }
    end

    context "when user is admin" do
      let(:user) { admin }
      it { is_expected.to be_update }
    end
  end

  describe "#destroy?" do
    it { is_expected.to be_destroy }

    context "when user is another user" do
      let(:user) { other_user }
      it { is_expected.not_to be_destroy }
    end
  end

  describe "#test?" do
    it { is_expected.to be_test }

    context "when user is another user" do
      let(:user) { other_user }
      it { is_expected.not_to be_test }
    end

    context "when user is admin" do
      let(:user) { admin }
      it { is_expected.to be_test }
    end
  end

  describe ".relation_scope" do
    subject(:scope) { policy.apply_scope(Notification.all, type: :relation) }

    let(:policy) { described_class.new(nil, user: owner) }
    let(:owner) { create(:user) }
    let(:other_user) { create(:user) }

    before do
      create(:notification, user: owner)
      create(:notification, user: other_user)
    end

    it "returns only the user's own notifications" do
      expect(scope.count).to eq(1)
    end

    context "when user is admin" do
      let(:policy) { described_class.new(nil, user: admin) }
      let(:admin) { create(:user, :admin) }

      it "returns all notifications" do
        expect(scope.count).to eq(2)
      end
    end
  end
end
```

- [ ] **Step 2: Run spec to confirm failure**

Run: `docker compose exec app bundle exec rspec spec/policies/notification_policy_spec.rb`
Expected: FAIL — `NotificationPolicy` not defined.

- [ ] **Step 3: Implement policy**

`app/policies/notification_policy.rb`:

```ruby
# frozen_string_literal: true

class NotificationPolicy < ApplicationPolicy
  authorize :user

  scope_for :relation do |relation|
    next relation if user.admin?

    relation.where(user:)
  end

  def index?
    user.present?
  end

  def show?
    user.admin? || record.user == user
  end

  def create?
    user.admin? || record.user == user
  end

  def update?
    user.admin? || record.user == user
  end

  def destroy?
    update?
  end

  def test?
    update?
  end
end
```

- [ ] **Step 4: Run spec**

Run: `docker compose exec app bundle exec rspec spec/policies/notification_policy_spec.rb`
Expected: PASS.

- [ ] **Step 5: Run rubocop**

Run: `docker compose exec app bundle exec rubocop app/policies/notification_policy.rb spec/policies/notification_policy_spec.rb`

- [ ] **Step 6: Commit**

```bash
git add app/policies/notification_policy.rb spec/policies/notification_policy_spec.rb
git commit -m "Add notification policy"
```

---

## Task 7: Notifications controller + routes + views + i18n

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/notifications_controller.rb`
- Create: `app/views/notifications/index.html.erb`
- Create: `app/views/notifications/_notification.html.erb`
- Create: `app/views/notifications/_form.html.erb`
- Create: `app/views/notifications/new.html.erb`
- Create: `app/views/notifications/edit.html.erb`
- Create: `config/locales/notifications.en.yml`
- Create: `spec/requests/notifications_request_spec.rb`

This task does not yet wire up the `test` member action or the `Notifications::TestService` — that comes in Task 9 once the service exists. The route is added now (so the URL helpers exist), but the controller stubs the action with `head :not_implemented` until Task 9.

- [ ] **Step 1: Add routes**

In `config/routes.rb`, after the existing `resources :servers do … end` block, add:

```ruby
  resources :notifications do
    member do
      post :test
    end
  end
```

- [ ] **Step 2: Annotate routes**

Run: `docker compose exec app bundle exec annotaterb routes`

- [ ] **Step 3: Create i18n file `config/locales/notifications.en.yml`**

```yaml
en:
  notifications:
    actions:
      delete: Delete notification
      delete_confirm: Are you sure you want to delete this notification? This action cannot be undone.
      delete_confirm_title: Delete notification
      edit: Edit notification
      test: Send test notification
    create:
      success: Notification was successfully created.
    destroy:
      success: Notification was successfully deleted.
    edit:
      title: Edit notification
    form:
      description: Description
      description_placeholder: Optional description for this notification
      details: Details
      enabled: Enabled
      name: Name
      name_placeholder: My Slack channel
      submit_create: Create notification
      submit_update: Update notification
      test_button: Send test
      url: Apprise URL
      url_hint: Apprise notification URL (e.g. slack://, discord://, mailto://, json://)
      url_placeholder: slack://TokenA/TokenB/TokenC/#channel
      url_placeholder_edit: Leave blank to keep unchanged
      credentials_encrypted_hint: The notification URL is securely encrypted and stored in the database.
    index:
      empty: No notifications have been configured yet.
      new: New notification
      search:
        no_results:
          title: No notifications found
        placeholder: Search by name or description...
      subtitle: Manage notification destinations for job lifecycle events
      title: Notifications
    new:
      subtitle: Add a new notification destination
      title: New notification
    table:
      enabled: Enabled
      name: Name
    test:
      success: Test notification was sent successfully.
      failure: 'Test notification failed: %{error}'
    title: Notifications
    update:
      success: Notification was successfully updated.
  activerecord:
    errors:
      models:
        notification:
          attributes:
            url:
              invalid: must be a valid URL with a scheme (e.g. slack://, mailto://)
```

Run: `docker compose exec app bundle exec i18n-tasks normalize`

- [ ] **Step 4: Create the controller**

`app/controllers/notifications_controller.rb`:

```ruby
# frozen_string_literal: true

class NotificationsController < ApplicationController
  include Searchable
  include Sortable

  before_action :authenticate_user!
  before_action :ensure_notifications_enabled
  before_action :set_notification, only: [:edit, :update, :destroy, :test]

  def index
    notifications = authorized_scope(Notification.all, type: :relation)
    notifications = search_for(notifications, "name", "description")
    notifications = sort_for(notifications, allowed: ["name"], default: { name: :asc })

    @pagy, @notifications = pagy(notifications)

    authorize! :notification
  end

  def new
    @notification = Notification.new(enabled: true)
    @notification.user = current_user

    authorize! @notification
  end

  def edit
    authorize! @notification
  end

  def create
    @notification = current_user.notifications.build(notification_params)

    authorize! @notification

    if @notification.save
      redirect_to notifications_path, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @notification

    if @notification.update(update_params)
      redirect_to notifications_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @notification

    @notification.destroy!

    redirect_to notifications_path, notice: t(".success"), status: :see_other
  end

  def test
    authorize! @notification

    # Wired up in a later task; placeholder for now.
    head :not_implemented
  end

  private

  def set_notification
    @notification = Notification.find(params[:id])
  end

  def ensure_notifications_enabled
    raise ActionController::RoutingError, "Not Found" unless Configuration.get("notifications")
  end

  def notification_params
    params.require(:notification).permit(:name, :description, :url, :enabled)
  end

  def update_params
    permitted = notification_params
    permitted.delete(:url) if permitted[:url].blank?
    permitted
  end
end
```

- [ ] **Step 5: Create views**

`app/views/notifications/index.html.erb` — copy structure from `app/views/servers/index.html.erb`, adapting:
- title/subtitle/empty keys to `notifications.index.*`,
- search frame to `notifications_list`,
- new path to `new_notification_path`,
- empty-state icon to `bell`,
- table columns: Name, Enabled.

For each row, render `app/views/notifications/_notification.html.erb`:

```erb
<tr>
  <td><%= notification.name %></td>
  <td>
    <% if notification.enabled? %>
      <%= lucide_icon "check", class: "h-4 w-4 text-green-500" %>
    <% else %>
      <%= lucide_icon "x", class: "h-4 w-4 text-gray-400" %>
    <% end %>
  </td>
  <td class="text-right">
    <%= link_to edit_notification_path(notification),
                data: { tooltip: I18n.t("notifications.actions.edit") },
                class: "btn-icon-outline btn-icon-sm" do %>
      <%= lucide_icon "pencil", class: "h-4 w-4" %>
    <% end %>

    <%= button_to notification_path(notification),
                  method: :delete,
                  data: {
                    turbo_confirm: I18n.t("notifications.actions.delete_confirm"),
                    turbo_confirm_title: I18n.t("notifications.actions.delete_confirm_title"),
                    tooltip: I18n.t("notifications.actions.delete"),
                  },
                  class: "btn-icon-outline btn-icon-sm" do %>
      <%= lucide_icon "trash-2", class: "h-4 w-4" %>
    <% end %>
  </td>
</tr>
```

`app/views/notifications/_form.html.erb` — minimal form with two cards (Details + URL), modeled on `app/views/repositories/_form.html.erb`. Fields: `name` (text), `description` (textarea), `enabled` (checkbox), `url` (password_field-style — masked, with `placeholder_edit` when persisted, blank means keep). Include "Send test" button (`button_to test_notification_path(notification), method: :post`) only when `notification.persisted?`. Use `I18n.t("notifications.form.*")` keys throughout. End with the encrypted-credentials hint paragraph.

`app/views/notifications/new.html.erb`:

```erb
<% content_for :title do %>
  <%= I18n.t("notifications.new.title") %>
<% end %>

<% content_for :subtitle do %>
  <%= I18n.t("notifications.new.subtitle") %>
<% end %>

<%= render "form", notification: @notification %>
```

`app/views/notifications/edit.html.erb`:

```erb
<% content_for :title do %>
  <%= I18n.t("notifications.edit.title") %>
<% end %>

<%= render "form", notification: @notification %>
```

- [ ] **Step 6: Format ERB**

Run: `docker compose exec app yarn herb:format`

- [ ] **Step 7: Write request spec**

`spec/requests/notifications_request_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe "Notifications" do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /notifications" do
    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "renders the index page" do
        get notifications_path
        expect(response).to have_http_status(:ok)
      end

      it "filters by query" do
        match    = create(:notification, user:, name: "Production Slack")
        no_match = create(:notification, user:, name: "Staging email")

        get notifications_path, params: { query: "production" }

        expect(response.body).to include(match.name)
        expect(response.body).not_to include(no_match.name)
      end

      context "when feature is disabled" do
        before { Configuration.set("notifications", false) }

        it "returns 404" do
          get notifications_path
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get notifications_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /notifications" do
    let(:valid_params) { { notification: { name: "Slack", url: "slack://x/y/z/#chan", enabled: true } } }

    before { sign_in user, scope: :user }

    it "creates the notification for the current user" do
      expect { post notifications_path, params: valid_params }
        .to change(user.notifications, :count).by(1)

      expect(response).to redirect_to(notifications_path)
    end

    it "renders new with errors when invalid" do
      post notifications_path, params: { notification: { name: "", url: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /notifications/:id" do
    let(:notification) { create(:notification, user:, url: "slack://orig/url") }

    before { sign_in user, scope: :user }

    it "updates name" do
      patch notification_path(notification), params: { notification: { name: "New" } }

      expect(notification.reload.name).to eq("New")
    end

    it "does not clear url when blank" do
      expect do
        patch notification_path(notification), params: { notification: { url: "" } }
      end.not_to(change { notification.reload.url })
    end

    it "forbids updates to other users' notifications" do
      other = create(:notification, user: other_user)

      patch notification_path(other), params: { notification: { name: "Hacked" } }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /notifications/:id" do
    let!(:notification) { create(:notification, user:) }

    before { sign_in user, scope: :user }

    it "destroys" do
      expect { delete notification_path(notification) }
        .to change(Notification, :count).by(-1)
    end

    it "forbids destroy of other users' notifications" do
      other = create(:notification, user: other_user)

      delete notification_path(other)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /notifications/new" do
    before { sign_in user, scope: :user }

    it "renders" do
      get new_notification_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /notifications/:id/edit" do
    let(:notification) { create(:notification, user:) }

    before { sign_in user, scope: :user }

    it "renders" do
      get edit_notification_path(notification)
      expect(response).to have_http_status(:ok)
    end

    it "forbids editing other users' notifications" do
      other = create(:notification, user: other_user)

      get edit_notification_path(other)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
```

- [ ] **Step 8: Run tests**

Run: `docker compose exec app bundle exec rspec spec/requests/notifications_request_spec.rb`
Expected: all pass.

- [ ] **Step 9: Run rubocop**

Run: `docker compose exec app bundle exec rubocop app/controllers/notifications_controller.rb spec/requests/notifications_request_spec.rb config/routes.rb`

- [ ] **Step 10: Commit**

```bash
git add config/routes.rb app/controllers/notifications_controller.rb \
        app/views/notifications config/locales/notifications.en.yml \
        spec/requests/notifications_request_spec.rb
git commit -m "Add notifications controller, views, and routes"
```

---

## Task 8: `Notifications::RenderService` + body templates

**Files:**
- Create: `app/services/notifications/render_service.rb`
- Create: `app/views/notifications/_start.text.erb`
- Create: `app/views/notifications/_success.text.erb`
- Create: `app/views/notifications/_failure.text.erb`
- Create: `spec/services/notifications/render_service_spec.rb`
- Modify: `config/locales/notifications.en.yml`

- [ ] **Step 1: Add i18n keys**

In `config/locales/notifications.en.yml`, append under `notifications:`:

```yaml
    events:
      start:
        title: 'Job started: %{job}'
      success:
        title: 'Job completed: %{job}'
      failure:
        title: 'Job failed: %{job}'
    body:
      job_name: 'Job'
      job_id: 'Job ID'
      source: 'Source'
      destination: 'Destination'
      started_at: 'Started at'
      completed_at: 'Completed at'
      duration: 'Duration'
      trigger: 'Trigger'
      triggered_by: 'Triggered by'
      error_class: 'Error class'
      error_message: 'Error message'
      log_url: 'Log URL'
```

Run: `docker compose exec app bundle exec i18n-tasks normalize`

- [ ] **Step 2: Write spec first**

`spec/services/notifications/render_service_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Notifications::RenderService do
  let(:job_run) do
    create(:job_run,
           status: "running",
           trigger: "manual",
           started_at: Time.zone.parse("2026-05-01 10:00:00"))
  end

  describe "#call" do
    context "with start event" do
      subject(:result) { described_class.new(job_run, "start").call }

      it "returns title, body, and notification_type" do
        expect(result[:title]).to eq("Job started: #{job_run.job.name}")
        expect(result[:body]).to include(job_run.job.name)
        expect(result[:body]).to include(job_run.id)
        expect(result[:notification_type]).to eq("info")
      end
    end

    context "with success event" do
      subject(:result) { described_class.new(job_run, "success").call }

      before do
        job_run.update!(status: "completed", completed_at: Time.zone.parse("2026-05-01 10:05:00"))
      end

      it "includes completed_at and duration" do
        expect(result[:body]).to include("Completed at")
        expect(result[:body]).to include("Duration")
        expect(result[:notification_type]).to eq("success")
      end
    end

    context "with failure event" do
      subject(:result) { described_class.new(job_run, "failure").call }

      before do
        job_run.update!(
          status: "errored",
          completed_at: Time.zone.parse("2026-05-01 10:02:00"),
          error_class: "Errno::ENOENT",
          error_message: "No such file or directory",
        )
      end

      it "includes error fields and notification_type failure" do
        expect(result[:body]).to include("Errno::ENOENT")
        expect(result[:body]).to include("No such file or directory")
        expect(result[:notification_type]).to eq("failure")
      end
    end
  end
end
```

- [ ] **Step 3: Run spec to confirm failure**

Run: `docker compose exec app bundle exec rspec spec/services/notifications/render_service_spec.rb`
Expected: FAIL — `Notifications::RenderService` not defined.

- [ ] **Step 4: Implement service**

`app/services/notifications/render_service.rb`:

```ruby
# frozen_string_literal: true

module Notifications
  class RenderService < ApplicationService
    attr_reader :job_run, :event

    def initialize(job_run, event)
      super()

      @job_run = job_run
      @event = event
    end

    def call
      {
        title:,
        body:,
        notification_type:,
      }
    end

    private

    def notification_type
      case event
      when "start" then "info"
      else event
      end
    end

    def title
      I18n.t("notifications.events.#{event}.title", job: job_run.job.name)
    end

    def body
      ApplicationController.render(
        partial: "notifications/#{event}",
        locals: { job_run: job_run },
      )
    end
  end
end
```

- [ ] **Step 5: Implement body templates**

`app/views/notifications/_start.text.erb`:

```erb
**<%= t("notifications.body.job_name") %>:** <%= job_run.job.name %>
**<%= t("notifications.body.job_id") %>:** <%= job_run.id %>
**<%= t("notifications.body.source") %>:** <%= job_run.job.source_repository.name %>
**<%= t("notifications.body.destination") %>:** <%= job_run.job.destination_repository.name %>
**<%= t("notifications.body.started_at") %>:** <%= l(job_run.started_at, format: :long) %>
**<%= t("notifications.body.trigger") %>:** <%= job_run.trigger %>
**<%= t("notifications.body.triggered_by") %>:** <%= job_run.user.email %>
```

`app/views/notifications/_success.text.erb`:

```erb
**<%= t("notifications.body.job_name") %>:** <%= job_run.job.name %>
**<%= t("notifications.body.job_id") %>:** <%= job_run.id %>
**<%= t("notifications.body.source") %>:** <%= job_run.job.source_repository.name %>
**<%= t("notifications.body.destination") %>:** <%= job_run.job.destination_repository.name %>
**<%= t("notifications.body.started_at") %>:** <%= l(job_run.started_at, format: :long) %>
**<%= t("notifications.body.completed_at") %>:** <%= l(job_run.completed_at, format: :long) %>
**<%= t("notifications.body.duration") %>:** <%= distance_of_time_in_words(job_run.duration) %>
**<%= t("notifications.body.trigger") %>:** <%= job_run.trigger %>
**<%= t("notifications.body.triggered_by") %>:** <%= job_run.user.email %>
```

`app/views/notifications/_failure.text.erb`:

```erb
**<%= t("notifications.body.job_name") %>:** <%= job_run.job.name %>
**<%= t("notifications.body.job_id") %>:** <%= job_run.id %>
**<%= t("notifications.body.source") %>:** <%= job_run.job.source_repository.name %>
**<%= t("notifications.body.destination") %>:** <%= job_run.job.destination_repository.name %>
**<%= t("notifications.body.started_at") %>:** <%= l(job_run.started_at, format: :long) %>
**<%= t("notifications.body.completed_at") %>:** <%= l(job_run.completed_at, format: :long) if job_run.completed_at %>
**<%= t("notifications.body.duration") %>:** <%= distance_of_time_in_words(job_run.duration) if job_run.duration %>
**<%= t("notifications.body.trigger") %>:** <%= job_run.trigger %>
**<%= t("notifications.body.triggered_by") %>:** <%= job_run.user.email %>
**<%= t("notifications.body.error_class") %>:** <%= job_run.error_class %>
**<%= t("notifications.body.error_message") %>:** <%= job_run.error_message %>
**<%= t("notifications.body.log_url") %>:** <%= job_run_url(job_run) %>
```

- [ ] **Step 6: Format ERB and run spec**

Run:
```
docker compose exec app yarn herb:format
docker compose exec app bundle exec rspec spec/services/notifications/render_service_spec.rb
```
Expected: spec passes.

- [ ] **Step 7: Run rubocop**

Run: `docker compose exec app bundle exec rubocop app/services/notifications/render_service.rb spec/services/notifications/render_service_spec.rb`

- [ ] **Step 8: Commit**

```bash
git add app/services/notifications/render_service.rb app/views/notifications \
        spec/services/notifications/render_service_spec.rb \
        config/locales/notifications.en.yml
git commit -m "Add notification render service"
```

---

## Task 9: `Notifications::SendService` + `Notifications::TestService` + wire up controller `test`

**Files:**
- Create: `app/services/notifications/send_service.rb`
- Create: `app/services/notifications/test_service.rb`
- Create: `spec/services/notifications/send_service_spec.rb`
- Create: `spec/services/notifications/test_service_spec.rb`
- Modify: `app/controllers/notifications_controller.rb`
- Modify: `spec/requests/notifications_request_spec.rb`

- [ ] **Step 1: Write `send_service_spec.rb`**

```ruby
# frozen_string_literal: true

RSpec.describe Notifications::SendService do
  let(:notification) { create(:notification, url: "json://example.com/hook") }
  let(:job_run) { create(:job_run) }

  before do
    allow(Notifications::RenderService)
      .to receive_message_chain(:new, :call)
      .and_return(title: "T", body: "B", notification_type: "info")
  end

  describe "#call" do
    context "when apprise succeeds" do
      before do
        allow(Open3)
          .to receive(:capture3)
          .and_return(["ok", "", instance_double(Process::Status, success?: true)])
      end

      it "invokes apprise with stdin URL" do
        described_class.new(notification, job_run, "start").call

        expect(Open3).to have_received(:capture3) do |env, *args, **opts|
          expect(args).to include("apprise")
          expect(args).to include("--config=-")
          expect(args).to include("--title=T")
          expect(args).to include("--body=B")
          expect(args).to include("--notification-type=info")
          expect(opts[:stdin_data]).to eq("json://example.com/hook\n")
        end
      end

      it "returns success result" do
        result = described_class.new(notification, job_run, "start").call

        expect(result[:success]).to be(true)
      end
    end

    context "when apprise fails" do
      before do
        allow(Open3)
          .to receive(:capture3)
          .and_return(["", "boom", instance_double(Process::Status, success?: false)])
      end

      it "returns failure result with output" do
        result = described_class.new(notification, job_run, "start").call

        expect(result[:success]).to be(false)
        expect(result[:output]).to include("boom")
      end
    end

    context "when apprise times out" do
      before do
        allow(Open3).to receive(:capture3).and_raise(Timeout::Error)
      end

      it "returns failure result without raising" do
        result = described_class.new(notification, job_run, "start").call

        expect(result[:success]).to be(false)
      end
    end
  end
end
```

- [ ] **Step 2: Implement `send_service.rb`**

`app/services/notifications/send_service.rb`:

```ruby
# frozen_string_literal: true

module Notifications
  class SendService < ApplicationService
    DEFAULT_TIMEOUT = 30

    attr_reader :notification, :job_run, :event, :timeout

    def initialize(notification, job_run, event, timeout: DEFAULT_TIMEOUT)
      super()

      @notification = notification
      @job_run = job_run
      @event = event
      @timeout = timeout
    end

    def call
      rendered = RenderService.new(job_run, event).call

      stdout, stderr, status = Timeout.timeout(timeout) do
        Open3.capture3(
          "apprise",
          "--input-format=markdown",
          "--title=#{rendered[:title]}",
          "--body=#{rendered[:body]}",
          "--notification-type=#{rendered[:notification_type]}",
          "--config=-",
          stdin_data: "#{notification.url}\n",
        )
      end

      { success: status.success?, output: "#{stdout}\n#{stderr}".strip }
    rescue Timeout::Error => e
      { success: false, output: "Timeout after #{timeout}s: #{e.message}" }
    end
  end
end
```

- [ ] **Step 3: Write `test_service_spec.rb`**

```ruby
# frozen_string_literal: true

RSpec.describe Notifications::TestService do
  let(:notification) { create(:notification, name: "My Slack", url: "json://example.com/hook") }

  describe "#call" do
    context "when apprise succeeds" do
      before do
        allow(Open3)
          .to receive(:capture3)
          .and_return(["ok", "", instance_double(Process::Status, success?: true)])
      end

      it "returns success" do
        result = described_class.new(notification).call

        expect(result[:success]).to be(true)
      end

      it "sends a synthetic title and body" do
        described_class.new(notification).call

        expect(Open3).to have_received(:capture3) do |*args, **opts|
          joined = args.join(" ")
          expect(joined).to include("--title=")
          expect(joined).to include("--body=")
          expect(opts[:stdin_data]).to eq("json://example.com/hook\n")
        end
      end
    end

    context "when apprise fails" do
      before do
        allow(Open3)
          .to receive(:capture3)
          .and_return(["", "denied", instance_double(Process::Status, success?: false)])
      end

      it "returns failure with stderr in message" do
        result = described_class.new(notification).call

        expect(result[:success]).to be(false)
        expect(result[:message]).to include("denied")
      end
    end
  end
end
```

- [ ] **Step 4: Implement `test_service.rb`**

`app/services/notifications/test_service.rb`:

```ruby
# frozen_string_literal: true

module Notifications
  class TestService < ApplicationService
    TIMEOUT = 10

    attr_reader :notification

    def initialize(notification)
      super()

      @notification = notification
    end

    def call
      stdout, stderr, status = Timeout.timeout(TIMEOUT) do
        Open3.capture3(
          "apprise",
          "--input-format=markdown",
          "--title=#{title}",
          "--body=#{body}",
          "--notification-type=info",
          "--config=-",
          stdin_data: "#{notification.url}\n",
        )
      end

      if status.success?
        { success: true, message: stdout.strip }
      else
        { success: false, message: "#{stdout}\n#{stderr}".strip }
      end
    rescue Timeout::Error => e
      { success: false, message: "Timeout after #{TIMEOUT}s: #{e.message}" }
    end

    private

    def title
      I18n.t("notifications.test.title_default", default: "Test notification from Rsync UI")
    end

    def body
      I18n.t("notifications.test.body_default", name: notification.name)
    end
  end
end
```

Add to `config/locales/notifications.en.yml` under `notifications:`:

```yaml
    test:
      success: Test notification was sent successfully.
      failure: 'Test notification failed: %{error}'
      title_default: Test notification from Rsync UI
      body_default: 'This is a test notification from Rsync UI for **%{name}**.'
```

(Replace the simpler `test:` block from Task 7 — those keys are merged here.)

Run: `docker compose exec app bundle exec i18n-tasks normalize`

- [ ] **Step 5: Wire up controller `test` action**

In `app/controllers/notifications_controller.rb`, replace the `test` method:

```ruby
def test
  authorize! @notification

  result = Notifications::TestService.call(@notification)

  if result[:success]
    redirect_to notifications_path, notice: t(".success")
  else
    redirect_to notifications_path, alert: t(".failure", error: result[:message])
  end
end
```

- [ ] **Step 6: Add request specs for `test` action**

Append to `spec/requests/notifications_request_spec.rb`:

```ruby
  describe "POST /notifications/:id/test" do
    let(:notification) { create(:notification, user:) }

    before { sign_in user, scope: :user }

    it "redirects with success flash on success" do
      allow(Notifications::TestService).to receive(:call).and_return(success: true, message: "ok")

      post test_notification_path(notification)

      follow_redirect!
      expect(response.body).to include(I18n.t("notifications.test.success"))
    end

    it "redirects with alert flash on failure" do
      allow(Notifications::TestService).to receive(:call).and_return(success: false, message: "denied")

      post test_notification_path(notification)

      follow_redirect!
      expect(response.body).to include("denied")
    end

    it "forbids testing other users' notifications" do
      other = create(:notification, user: other_user)

      post test_notification_path(other)

      expect(response).to have_http_status(:forbidden)
    end
  end
```

- [ ] **Step 7: Run all related specs**

Run: `docker compose exec app bundle exec rspec spec/services/notifications spec/requests/notifications_request_spec.rb`
Expected: all pass.

- [ ] **Step 8: Run rubocop**

Run: `docker compose exec app bundle exec rubocop app/services/notifications app/controllers/notifications_controller.rb spec/services/notifications spec/requests/notifications_request_spec.rb`

- [ ] **Step 9: Commit**

```bash
git add app/services/notifications/send_service.rb \
        app/services/notifications/test_service.rb \
        app/controllers/notifications_controller.rb \
        spec/services/notifications/send_service_spec.rb \
        spec/services/notifications/test_service_spec.rb \
        spec/requests/notifications_request_spec.rb \
        config/locales/notifications.en.yml
git commit -m "Add notification send and test services"
```

---

## Task 10: `Notifications::SendJob`

**Files:**
- Create: `app/jobs/notifications/send_job.rb`
- Create: `spec/jobs/notifications/send_job_spec.rb`

- [ ] **Step 1: Write spec first**

`spec/jobs/notifications/send_job_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Notifications::SendJob do
  let(:job_record) { create(:job) }
  let(:notification) { create(:notification, user: job_record.user) }
  let(:job_run) { create(:job_run, job: job_record, user: job_record.user) }
  let!(:job_notification) { create(:job_notification, job: job_record, notification:, on_start: true) }

  before do
    allow(Notifications::SendService).to receive(:call).and_return(success: true, output: "")
  end

  describe "#perform" do
    it "calls SendService when feature enabled, jn enabled, notification enabled, and event flag true" do
      described_class.new.perform(job_notification.id, job_run.id, "start")

      expect(Notifications::SendService).to have_received(:call).with(notification, job_run, "start")
    end

    it "no-ops when feature disabled" do
      Configuration.set("notifications", false)

      described_class.new.perform(job_notification.id, job_run.id, "start")

      expect(Notifications::SendService).not_to have_received(:call)
    end

    it "no-ops when join row disabled" do
      job_notification.update!(enabled: false)

      described_class.new.perform(job_notification.id, job_run.id, "start")

      expect(Notifications::SendService).not_to have_received(:call)
    end

    it "no-ops when notification disabled" do
      notification.update!(enabled: false)

      described_class.new.perform(job_notification.id, job_run.id, "start")

      expect(Notifications::SendService).not_to have_received(:call)
    end

    it "no-ops when on_start is false" do
      job_notification.update!(on_start: false)

      described_class.new.perform(job_notification.id, job_run.id, "start")

      expect(Notifications::SendService).not_to have_received(:call)
    end

    it "no-ops when on_success is false for success event" do
      job_notification.update!(on_success: false)

      described_class.new.perform(job_notification.id, job_run.id, "success")

      expect(Notifications::SendService).not_to have_received(:call)
    end
  end
end
```

- [ ] **Step 2: Run spec to confirm failure**

Run: `docker compose exec app bundle exec rspec spec/jobs/notifications/send_job_spec.rb`
Expected: FAIL — `Notifications::SendJob` not defined.

- [ ] **Step 3: Implement job**

`app/jobs/notifications/send_job.rb`:

```ruby
# frozen_string_literal: true

module Notifications
  class SendJob < ApplicationJob
    queue_as :default

    EVENT_FLAGS = {
      "start"   => :on_start?,
      "success" => :on_success?,
      "failure" => :on_failure?,
    }.freeze

    def perform(job_notification_id, job_run_id, event)
      return unless Configuration.get("notifications")

      job_notification = JobNotification.find_by(id: job_notification_id)
      return if job_notification.nil?
      return unless job_notification.enabled?
      return unless job_notification.notification.enabled?
      return unless job_notification.public_send(EVENT_FLAGS.fetch(event))

      job_run = JobRun.find_by(id: job_run_id)
      return if job_run.nil?

      result = Notifications::SendService.call(job_notification.notification, job_run, event)

      Rails.logger.warn "[Notifications] delivery failed: #{result[:output]}" unless result[:success]
    end
  end
end
```

- [ ] **Step 4: Run spec**

Run: `docker compose exec app bundle exec rspec spec/jobs/notifications/send_job_spec.rb`
Expected: PASS.

- [ ] **Step 5: Run rubocop**

Run: `docker compose exec app bundle exec rubocop app/jobs/notifications/send_job.rb spec/jobs/notifications/send_job_spec.rb`

- [ ] **Step 6: Commit**

```bash
git add app/jobs/notifications/send_job.rb spec/jobs/notifications/send_job_spec.rb
git commit -m "Add notification send job"
```

---

## Task 11: Hook into `JobRuns::ExecuteService`

**Files:**
- Modify: `app/services/jobs/execute_service.rb`
- Modify: `spec/services/jobs/execute_service_spec.rb` (or create if missing — verify location with `ls spec/services/jobs`)

- [ ] **Step 1: Inspect existing execute service spec**

Run: `ls spec/services/jobs`

If `execute_service_spec.rb` exists, read it; otherwise create one. Below assumes it exists.

- [ ] **Step 2: Add specs for the enqueue hooks**

Add to the existing spec file:

```ruby
describe "notification hooks" do
  let(:user) { create(:user) }
  let(:job)  { create(:job, user:) }
  let(:notification) { create(:notification, user:) }
  let!(:job_notification) { create(:job_notification, job:, notification:) }

  before do
    allow(Open3).to receive(:popen2e).and_yield(
      StringIO.new(""),
      StringIO.new(""),
      instance_double(Process::Waiter, value: instance_double(Process::Status, success?: true, exitstatus: 0)),
    )
  end

  it "enqueues a start notification when execution begins" do
    expect { described_class.call(job, trigger: "manual") }
      .to have_enqueued_job(Notifications::SendJob)
      .with(an_instance_of(String), an_instance_of(String), "start")
  end

  it "enqueues a success notification when execution completes successfully" do
    expect { described_class.call(job, trigger: "manual") }
      .to have_enqueued_job(Notifications::SendJob)
      .with(an_instance_of(String), an_instance_of(String), "success")
  end

  it "does not enqueue when notifications config is disabled" do
    Configuration.set("notifications", false)

    expect { described_class.call(job, trigger: "manual") }
      .not_to have_enqueued_job(Notifications::SendJob)
  end
end
```

(If `popen2e` stubbing doesn't fit existing patterns, mirror what the current spec does for that mocking — read the file first.)

- [ ] **Step 3: Modify `app/services/jobs/execute_service.rb`**

Add at the bottom of the class (after the existing `private` section):

```ruby
def enqueue_notifications(job_run, event)
  return unless Configuration.get("notifications")

  job_run.job.job_notifications.find_each do |jn|
    Notifications::SendJob.perform_later(jn.id, job_run.id, event)
  end
end
```

In `#call`, after `job_run = job.job_runs.create!(...)` (the running-status creation), add:

```ruby
enqueue_notifications(job_run, "start")
```

After the success/failed status update line (`job_run.update!(status: exit_status.success? ? "completed" : "failed", completed_at: Time.zone.now)`), add:

```ruby
enqueue_notifications(job_run, exit_status.success? ? "success" : "failure")
```

In the `rescue StandardError` clause, after the `job_run.update!(status: "errored", ...)`, add:

```ruby
enqueue_notifications(job_run, "failure")
```

- [ ] **Step 4: Run specs**

Run: `docker compose exec app bundle exec rspec spec/services/jobs/execute_service_spec.rb spec/jobs/notifications/send_job_spec.rb`
Expected: all pass.

- [ ] **Step 5: Run rubocop**

Run: `docker compose exec app bundle exec rubocop app/services/jobs/execute_service.rb spec/services/jobs/execute_service_spec.rb`

- [ ] **Step 6: Commit**

```bash
git add app/services/jobs/execute_service.rb spec/services/jobs/execute_service_spec.rb
git commit -m "Send notifications on job lifecycle events"
```

---

## Task 12: Job form integration (notifications card)

**Files:**
- Modify: `app/controllers/jobs_controller.rb`
- Modify: `app/views/jobs/_form.html.erb`
- Modify: `spec/requests/jobs_request_spec.rb`

- [ ] **Step 1: Permit nested attributes**

In `JobsController#job_params`, append to the `permit(...)` argument list:

```ruby
job_notifications_attributes: [
  :id, :notification_id, :enabled, :on_start, :on_success, :on_failure, :_destroy
],
```

- [ ] **Step 2: Add notifications card to `app/views/jobs/_form.html.erb`**

Find the left column (`<div class="flex flex-col gap-8">` block in the existing form). Append a new card inside that column, gated by config:

```erb
<% if Configuration.get("notifications") %>
  <div class="card">
    <header>
      <h2><%= I18n.t("jobs.form.notifications") %></h2>
    </header>

    <section>
      <% available = current_user.notifications.where(enabled: true).order(:name) %>

      <% if available.empty? %>
        <p class="text-sm text-muted-foreground">
          <%= I18n.t("jobs.form.notifications_empty_html",
                     link: link_to(I18n.t("jobs.form.notifications_empty_link"), notifications_path)).html_safe %>
        </p>
      <% else %>
        <div class="flex flex-col gap-4">
          <% available.each do |notif| %>
            <% existing = job.job_notifications.find { |jn| jn.notification_id == notif.id } %>
            <% jn = existing || job.job_notifications.build(notification: notif, enabled: false) %>

            <%= f.fields_for :job_notifications, jn do |jnf| %>
              <%= jnf.hidden_field :notification_id %>
              <% if jn.persisted? %>
                <%= jnf.hidden_field :id %>
              <% end %>

              <div class="flex flex-col gap-2 border rounded p-4">
                <div class="flex items-center justify-between">
                  <label class="font-medium">
                    <%= jnf.check_box :enabled %>
                    <%= notif.name %>
                  </label>
                </div>

                <div class="flex gap-4 text-sm">
                  <label><%= jnf.check_box :on_start %> <%= I18n.t("jobs.form.notifications_on_start") %></label>
                  <label><%= jnf.check_box :on_success %> <%= I18n.t("jobs.form.notifications_on_success") %></label>
                  <label><%= jnf.check_box :on_failure %> <%= I18n.t("jobs.form.notifications_on_failure") %></label>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      <% end %>
    </section>
  </div>
<% end %>
```

- [ ] **Step 3: Add jobs form i18n keys**

In `config/locales/en.yml`, under `jobs.form:`, add:

```yaml
      notifications: Notifications
      notifications_empty_html: 'No notifications configured. %{link} to add one.'
      notifications_empty_link: Create one
      notifications_on_start: On start
      notifications_on_success: On success
      notifications_on_failure: On failure
```

Run: `docker compose exec app bundle exec i18n-tasks normalize`

- [ ] **Step 4: Format ERB**

Run: `docker compose exec app yarn herb:format`

- [ ] **Step 5: Add request spec for nested attributes**

Append to `spec/requests/jobs_request_spec.rb`:

```ruby
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

    expect { post jobs_path, params: params }.to change(JobNotification, :count).by(1)
  end
end
```

(Adapt repository factory traits to whatever exists — read `spec/factories/repositories.rb` first if needed.)

- [ ] **Step 6: Run specs**

Run: `docker compose exec app bundle exec rspec spec/requests/jobs_request_spec.rb`
Expected: all pass.

- [ ] **Step 7: Run rubocop and herb format**

Run: `docker compose exec app bundle exec rubocop app/controllers/jobs_controller.rb spec/requests/jobs_request_spec.rb`
Run: `docker compose exec app yarn herb:format`

- [ ] **Step 8: Commit**

```bash
git add app/controllers/jobs_controller.rb app/views/jobs/_form.html.erb \
        config/locales/en.yml spec/requests/jobs_request_spec.rb
git commit -m "Allow attaching notifications on job form"
```

---

## Task 13: Navigation menu entry + check off PROJECT.md / NOTIFICATIONS.md

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Modify: `docs/PROJECT.md`
- Modify: `docs/features/NOTIFICATIONS.md`

- [ ] **Step 1: Add menu item**

In `app/views/layouts/application.html.erb`, after the existing `jobs_path` menu item line, add:

```erb
        <% if Configuration.get("notifications") %>
          <%= render "shared/menu/item", path: notifications_path, controllers: "notifications", icon: "bell", title: I18n.t("notifications.title") %>
        <% end %>
```

- [ ] **Step 2: Format**

Run: `docker compose exec app yarn herb:format`

- [ ] **Step 3: Update `docs/features/NOTIFICATIONS.md`**

Replace every `- [ ]` with `- [x]` for the items implemented (i.e. all of them in this plan).

- [ ] **Step 4: Update `docs/PROJECT.md`**

If the Notifications feature is listed there, mark its checkboxes. Otherwise no change.

- [ ] **Step 5: Smoke test in browser**

Run: `docker compose up -d` (if not already), then visit `http://localhost:3000`.

Manually verify:
- Notifications menu entry appears.
- Can create a notification with a `json://localhost/test` URL.
- Test button on the form returns a success or a clear error flash.
- Job form shows the notifications card when notifications exist; toggling checkboxes persists.
- Disabling the `notifications` config (via `/configurations`) hides the menu item and 404s `/notifications`.

(If browser testing is impractical in the execution environment, state explicitly: "smoke test deferred — UI not validated".)

- [ ] **Step 6: Commit**

```bash
git add app/views/layouts/application.html.erb docs/features/NOTIFICATIONS.md docs/PROJECT.md
git commit -m "Add notifications menu entry and check off feature"
```

---

## Final verification

- [ ] Run the full test suite: `docker compose exec app bundle exec rspec`
- [ ] Run rubocop on the full project: `docker compose exec app bundle exec rubocop`
- [ ] Run herb formatter check: `docker compose exec app yarn herb:format`
- [ ] Confirm migrations annotate cleanly: `docker compose exec app bundle exec annotaterb models && git diff --stat`
- [ ] Review the commit log: `git log --oneline main..HEAD` — should show ~13 atomic commits.
