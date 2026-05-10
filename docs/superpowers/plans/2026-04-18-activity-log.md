# Activity Log Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the `JobRun` model, policy, controller, views, and specs for the activity log feature.

**Architecture:** Top-level `JobRun` resource scoped by user. Read-only index listing runs in reverse chronological order. Destroy allowed for terminal statuses; cancel is a stubbed member action. Follows existing Rails conventions: UUID PKs, ActionPolicy, I18n, Hotwire/Turbo views.

**Tech Stack:** Rails 8, PostgreSQL, ActionPolicy, Devise, RSpec/FactoryBot/Shoulda Matchers, Tailwind CSS + Basecoat UI, Lucide icons.

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `db/migrate/<timestamp>_create_job_runs.rb` | Create | Database table for job runs |
| `app/models/job_run.rb` | Create | Model: associations, enums, callbacks, helpers |
| `spec/factories/job_runs.rb` | Create | Factory with status/trigger traits |
| `spec/models/job_run_spec.rb` | Create | Model spec |
| `app/policies/job_run_policy.rb` | Create | Authorization policy |
| `spec/policies/job_run_policy_spec.rb` | Create | Policy spec |
| `config/locales/en.yml` | Modify | Add `job_runs:` translation keys |
| `config/routes.rb` | Modify | Add `resources :job_runs` with cancel member action |
| `app/controllers/job_runs_controller.rb` | Create | Controller: index, destroy, cancel |
| `spec/requests/job_runs_request_spec.rb` | Create | Request spec |
| `app/views/job_runs/index.html.erb` | Create | Index table view |
| `app/views/job_runs/_job_run.html.erb` | Create | Table row partial |
| `app/views/layouts/application.html.erb` | Modify | Add Activity log menu item |

---

## Task 1: Database Migration

**Files:**
- Create: `db/migrate/<timestamp>_create_job_runs.rb`

- [ ] **Step 1: Generate the migration**

```bash
docker compose exec app bundle exec rails generate migration CreateJobRuns
```

Expected: creates `db/migrate/<timestamp>_create_job_runs.rb`

- [ ] **Step 2: Fill in the migration**

Replace the generated file content entirely with:

```ruby
# frozen_string_literal: true

class CreateJobRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :job_runs, id: :uuid do |t|
      t.references :job, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.integer :sequence, null: false
      t.string :trigger, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
  end
end
```

- [ ] **Step 3: Run the migration** (confirm with user first)

```bash
docker compose exec app bundle exec rails db:migrate
```

Expected output includes: `CreateJobRuns: migrated`

- [ ] **Step 4: Commit**

```bash
git add db/migrate/*_create_job_runs.rb db/schema.rb
git commit -m "Add job_runs table"
```

---

## Task 2: JobRun Model + Factory

**Files:**
- Create: `app/models/job_run.rb`
- Create: `spec/factories/job_runs.rb`

- [ ] **Step 1: Create the model**

Create `app/models/job_run.rb`:

```ruby
# frozen_string_literal: true

class JobRun < ApplicationRecord
  belongs_to :job
  belongs_to :user

  enum :trigger, { manual: "manual", scheduled: "scheduled" }, validate: true
  enum :status, { pending: "pending", running: "running", completed: "completed", failed: "failed", canceled: "canceled" }, validate: true

  validates :trigger, presence: true
  validates :status, presence: true

  before_create :assign_sequence

  def duration
    return nil unless started_at

    (completed_at || Time.current) - started_at
  end

  def deletable?
    completed? || failed? || canceled?
  end

  private

  def assign_sequence
    self.sequence = (self.class.where(job:).maximum(:sequence) || 0) + 1
  end
end
```

- [ ] **Step 2: Create the factory**

Create `spec/factories/job_runs.rb`:

```ruby
# frozen_string_literal: true

FactoryBot.define do
  factory :job_run do
    job
    user
    trigger { :manual }
    status { :pending }
    sequence { 1 }

    trait :pending do
      status { :pending }
      started_at { nil }
      completed_at { nil }
    end

    trait :running do
      status { :running }
      started_at { 5.minutes.ago }
      completed_at { nil }
    end

    trait :completed do
      status { :completed }
      started_at { 10.minutes.ago }
      completed_at { 5.minutes.ago }
    end

    trait :failed do
      status { :failed }
      started_at { 10.minutes.ago }
      completed_at { 5.minutes.ago }
    end

    trait :canceled do
      status { :canceled }
      started_at { nil }
      completed_at { nil }
    end
  end
end
```

- [ ] **Step 3: Annotate the model**

```bash
docker compose exec app bundle exec annotaterb models
```

Expected: adds schema comment block to `app/models/job_run.rb`

- [ ] **Step 4: Commit**

```bash
git add app/models/job_run.rb spec/factories/job_runs.rb
git commit -m "Add JobRun model and factory"
```

---

## Task 3: JobRun Model Spec

**Files:**
- Create: `spec/models/job_run_spec.rb`

- [ ] **Step 1: Write the model spec**

Create `spec/models/job_run_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe JobRun do
  subject(:job_run) { build(:job_run) }

  describe "associations" do
    it { is_expected.to belong_to(:job) }
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:trigger) }
    it { is_expected.to validate_presence_of(:status) }
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:trigger)
        .with_values(manual: "manual", scheduled: "scheduled")
        .backed_by_column_of_type(:string)
    }

    it {
      is_expected.to define_enum_for(:status)
        .with_values(pending: "pending", running: "running", completed: "completed", failed: "failed", canceled: "canceled")
        .backed_by_column_of_type(:string)
    }
  end

  describe "#deletable?" do
    it { expect(build(:job_run, :completed)).to be_deletable }
    it { expect(build(:job_run, :failed)).to be_deletable }
    it { expect(build(:job_run, :canceled)).to be_deletable }
    it { expect(build(:job_run, :pending)).not_to be_deletable }
    it { expect(build(:job_run, :running)).not_to be_deletable }
  end

  describe "#duration" do
    it "returns nil when started_at is blank" do
      job_run = build(:job_run, started_at: nil)

      expect(job_run.duration).to be_nil
    end

    it "returns elapsed seconds since started_at when running" do
      job_run = build(:job_run, :running, started_at: 5.minutes.ago, completed_at: nil)

      expect(job_run.duration).to be_within(1).of(5.minutes.to_i)
    end

    it "returns seconds from started_at to completed_at when completed" do
      job_run = build(:job_run, :completed, started_at: 10.minutes.ago, completed_at: 5.minutes.ago)

      expect(job_run.duration).to be_within(1).of(5.minutes.to_i)
    end
  end

  describe "sequence auto-assignment" do
    let(:job) { create(:job) }

    it "assigns sequence 1 for the first run of a job" do
      job_run = create(:job_run, job:)

      expect(job_run.sequence).to eq(1)
    end

    it "increments the sequence for subsequent runs of the same job" do
      create(:job_run, job:)
      second_run = create(:job_run, job:)

      expect(second_run.sequence).to eq(2)
    end

    it "sequences independently per job" do
      other_job = create(:job)
      create(:job_run, job:)
      run_for_other_job = create(:job_run, job: other_job)

      expect(run_for_other_job.sequence).to eq(1)
    end
  end
end
```

- [ ] **Step 2: Run the spec and verify it passes**

```bash
docker compose exec app bundle exec rspec spec/models/job_run_spec.rb
```

Expected: all examples pass.

- [ ] **Step 3: Commit**

```bash
git add spec/models/job_run_spec.rb
git commit -m "Add JobRun model spec"
```

---

## Task 4: JobRun Policy + Spec

**Files:**
- Create: `app/policies/job_run_policy.rb`
- Create: `spec/policies/job_run_policy_spec.rb`

- [ ] **Step 1: Write the failing policy spec**

Create `spec/policies/job_run_policy_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe JobRunPolicy do
  subject(:policy) { described_class.new(record, user:) }

  let(:owner) { build(:user) }
  let(:other_user) { build(:user) }
  let(:admin) { build(:user, :admin) }
  let(:record) { build(:job_run, user: owner) }
  let(:user) { owner }

  describe "#index?" do
    it { is_expected.to be_index }
  end

  describe "#destroy?" do
    it { is_expected.to be_destroy }

    context "when user is another user" do
      let(:user) { other_user }

      it { is_expected.not_to be_destroy }
    end

    context "when user is admin" do
      let(:user) { admin }

      it { is_expected.to be_destroy }
    end
  end

  describe "#cancel?" do
    it { is_expected.to be_cancel }

    context "when user is another user" do
      let(:user) { other_user }

      it { is_expected.not_to be_cancel }
    end

    context "when user is admin" do
      let(:user) { admin }

      it { is_expected.to be_cancel }
    end
  end

  describe ".relation_scope" do
    subject(:scope) { policy.apply_scope(JobRun.all, type: :relation) }

    let(:policy) { described_class.new(nil, user: owner) }
    let(:owner) { create(:user) }
    let(:other_user) { create(:user) }

    before do
      create(:job_run, user: owner)
      create(:job_run, user: other_user)
    end

    it "returns only the user's own job runs" do
      expect(scope.count).to eq(1)
    end

    context "when user is admin" do
      let(:policy) { described_class.new(nil, user: admin) }
      let(:admin) { create(:user, :admin) }

      it "returns all job runs" do
        expect(scope.count).to eq(2)
      end
    end
  end
end
```

- [ ] **Step 2: Run the spec to confirm it fails**

```bash
docker compose exec app bundle exec rspec spec/policies/job_run_policy_spec.rb
```

Expected: fails with `uninitialized constant JobRunPolicy`

- [ ] **Step 3: Create the policy**

Create `app/policies/job_run_policy.rb`:

```ruby
# frozen_string_literal: true

class JobRunPolicy < ApplicationPolicy
  authorize :user

  scope_for :relation do |relation|
    next relation if user.admin?

    relation.where(user:)
  end

  def index?
    user.present?
  end

  def destroy?
    user.admin? || record.user == user
  end

  def cancel?
    user.admin? || record.user == user
  end
end
```

- [ ] **Step 4: Run the spec and verify it passes**

```bash
docker compose exec app bundle exec rspec spec/policies/job_run_policy_spec.rb
```

Expected: all examples pass.

- [ ] **Step 5: Commit**

```bash
git add app/policies/job_run_policy.rb spec/policies/job_run_policy_spec.rb
git commit -m "Add JobRunPolicy and spec"
```

---

## Task 5: I18n Translations

**Files:**
- Modify: `config/locales/en.yml`

- [ ] **Step 1: Add translations**

In `config/locales/en.yml`, add the following block at the top level (alphabetically after `jobs:`, before `monitoring:`):

```yaml
  job_runs:
    actions:
      cancel: Cancel job run
      cancel_confirm: Are you sure you want to cancel this job run?
      cancel_confirm_title: Cancel job run
      delete: Delete job run
      delete_confirm: Are you sure you want to delete this job run? This action cannot be undone.
      delete_confirm_title: Delete job run
    destroy:
      success: Job run was successfully deleted.
    index:
      empty: No job runs have been recorded yet.
      subtitle: Overview of synchronization job executions
      title: Activity log
    status:
      canceled: Canceled
      completed: Completed
      failed: Failed
      pending: Pending
      running: Running
    table:
      completed_at: Completed at
      duration: Duration
      job: Job
      sequence: "#"
      started_at: Started at
      status: Status
      trigger: Trigger
    title: Activity log
    trigger:
      manual: Manual
      scheduled: Scheduled
```

- [ ] **Step 2: Normalize and verify**

```bash
docker compose exec app i18n-tasks normalize
```

Expected: no errors; file is reformatted if needed.

- [ ] **Step 3: Commit**

```bash
git add config/locales/en.yml
git commit -m "Add job_runs I18n translations"
```

---

## Task 6: Routes

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Add the job_runs resource**

In `config/routes.rb`, add after `resources :jobs, except: :show`:

```ruby
  resources :job_runs, only: [:index, :destroy] do
    member do
      patch :cancel
    end
  end
```

- [ ] **Step 2: Annotate routes**

```bash
docker compose exec app bundle exec annotaterb routes
```

Expected: updates the `# == Route Map` comment in `config/routes.rb` and all affected controllers.

- [ ] **Step 3: Commit**

```bash
git add config/routes.rb app/controllers/
git commit -m "Add job_runs routes"
```

---

## Task 7: Controller + Request Spec

**Files:**
- Create: `app/controllers/job_runs_controller.rb`
- Create: `spec/requests/job_runs_request_spec.rb`

- [ ] **Step 1: Write the failing request spec**

Create `spec/requests/job_runs_request_spec.rb`:

```ruby
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
```

- [ ] **Step 2: Run the spec to confirm it fails**

```bash
docker compose exec app bundle exec rspec spec/requests/job_runs_request_spec.rb
```

Expected: fails with `uninitialized constant JobRunsController`

- [ ] **Step 3: Create the controller**

Create `app/controllers/job_runs_controller.rb`:

```ruby
# frozen_string_literal: true

class JobRunsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_job_run, only: [:destroy, :cancel]

  def index
    @job_runs = authorized_scope(
      JobRun.includes(job: [:source_repository, :destination_repository]).order(created_at: :desc),
      type: :relation,
    )

    authorize! :job_run
  end

  def destroy
    authorize! @job_run

    unless @job_run.deletable?
      head :unprocessable_content
      return
    end

    @job_run.destroy!

    redirect_to job_runs_path, notice: t(".success"), status: :see_other
  end

  def cancel
    authorize! @job_run

    raise NotImplementedError
  end

  private

  def set_job_run
    @job_run = JobRun.find(params[:id])
  end
end
```

- [ ] **Step 4: Run the spec and verify it passes**

```bash
docker compose exec app bundle exec rspec spec/requests/job_runs_request_spec.rb
```

Expected: all examples pass.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/job_runs_controller.rb spec/requests/job_runs_request_spec.rb
git commit -m "Add JobRunsController and request spec"
```

---

## Task 8: Views

**Files:**
- Create: `app/views/job_runs/index.html.erb`
- Create: `app/views/job_runs/_job_run.html.erb`

- [ ] **Step 1: Create the index view**

Create `app/views/job_runs/index.html.erb`:

```erb
<% content_for :title do %>
  <%= I18n.t("job_runs.index.title") %>
<% end %>

<% content_for :subtitle do %>
  <%= I18n.t("job_runs.index.subtitle") %>
<% end %>

<% if @job_runs.empty? %>
  <div class="card flex flex-col items-center justify-center py-16 gap-4 text-gray-400">
    <%= lucide_icon "clock", class: "h-12 w-12" %>

    <p class="text-lg">
      <%= I18n.t("job_runs.index.empty") %>
    </p>
  </div>
<% else %>
  <div class="card p-0 overflow-hidden">
    <table class="w-full text-sm">
      <thead>
        <tr class="border-b border-gray-100 dark:border-gray-700">
          <th class="px-6 py-4 text-left font-medium text-gray-500 dark:text-gray-400">
            <%= I18n.t("job_runs.table.sequence") %>
          </th>

          <th class="px-6 py-4 text-left font-medium text-gray-500 dark:text-gray-400">
            <%= I18n.t("job_runs.table.job") %>
          </th>

          <th class="px-6 py-4 text-left font-medium text-gray-500 dark:text-gray-400">
            <%= I18n.t("job_runs.table.trigger") %>
          </th>

          <th class="px-6 py-4 text-left font-medium text-gray-500 dark:text-gray-400">
            <%= I18n.t("job_runs.table.status") %>
          </th>

          <th class="px-6 py-4 text-left font-medium text-gray-500 dark:text-gray-400">
            <%= I18n.t("job_runs.table.started_at") %>
          </th>

          <th class="px-6 py-4 text-left font-medium text-gray-500 dark:text-gray-400">
            <%= I18n.t("job_runs.table.duration") %>
          </th>

          <th class="px-6 py-4 text-left font-medium text-gray-500 dark:text-gray-400">
            <%= I18n.t("job_runs.table.completed_at") %>
          </th>

          <th class="px-6 py-4"></th>
        </tr>
      </thead>

      <tbody>
        <% @job_runs.each do |job_run| %>
          <%= render "job_run", job_run: %>
        <% end %>
      </tbody>
    </table>
  </div>
<% end %>
```

- [ ] **Step 2: Create the row partial**

Create `app/views/job_runs/_job_run.html.erb`:

```erb
<tr
  class="
    border-b border-gray-100 dark:border-gray-700 last:border-b-0
    hover:bg-gray-50 dark:hover:bg-gray-700/50
  "
>
  <td class="px-6 py-4 font-mono text-gray-600 dark:text-gray-300">
    #<%= job_run.sequence %>
  </td>

  <td class="px-6 py-4">
    <div class="font-medium text-gray-900 dark:text-gray-100">
      <%= link_to job_run.job.name, edit_job_path(job_run.job), class: "hover:underline" %>
    </div>
  </td>

  <td class="px-6 py-4">
    <span class="inline-flex items-center gap-1 rounded-full px-2 py-1 text-xs bg-gray-50 dark:bg-gray-700 text-gray-700 dark:text-gray-300">
      <%= I18n.t("job_runs.trigger.#{job_run.trigger}") %>
    </span>
  </td>

  <td class="px-6 py-4">
    <%
      status_classes = {
        "pending"   => "bg-gray-50 dark:bg-gray-700 text-gray-700 dark:text-gray-300",
        "running"   => "bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300",
        "completed" => "bg-green-50 dark:bg-green-900/30 text-green-700 dark:text-green-300",
        "failed"    => "bg-red-50 dark:bg-red-900/30 text-red-700 dark:text-red-300",
        "canceled"  => "bg-gray-50 dark:bg-gray-700 text-gray-700 dark:text-gray-300",
      }
    %>
    <span class="inline-flex items-center gap-1 rounded-full px-2 py-1 text-xs <%= status_classes[job_run.status] %>">
      <%= I18n.t("job_runs.status.#{job_run.status}") %>
    </span>
  </td>

  <td class="px-6 py-4 text-gray-600 dark:text-gray-300">
    <%= job_run.started_at ? l(job_run.started_at, format: :short) : "—" %>
  </td>

  <td class="px-6 py-4 text-gray-600 dark:text-gray-300">
    <% if job_run.started_at.present? %>
      <%= distance_of_time_in_words(job_run.started_at, job_run.completed_at || Time.current) %>
    <% else %>
      —
    <% end %>
  </td>

  <td class="px-6 py-4 text-gray-600 dark:text-gray-300">
    <%= job_run.completed_at ? l(job_run.completed_at, format: :short) : "—" %>
  </td>

  <td class="px-6 py-4">
    <div class="flex items-center justify-end gap-2">
      <% if job_run.deletable? %>
        <%= link_to job_run_path(job_run),
                    class: "btn-icon-outline btn-icon-md text-red-600 hover:text-red-700 dark:text-red-400",
                    title: I18n.t("job_runs.actions.delete"),
                    data: {
                      "turbo-method": :delete,
                      "turbo-confirm": I18n.t("job_runs.actions.delete_confirm"),
                      "turbo-confirm-title": I18n.t("job_runs.actions.delete_confirm_title"),
                      "turbo-confirm-destructive": true,
                    } do %>
          <%= lucide_icon "trash-2", class: "h-4 w-4" %>
        <% end %>
      <% elsif job_run.pending? || job_run.running? %>
        <%= link_to cancel_job_run_path(job_run),
                    class: "btn-icon-outline btn-icon-md",
                    title: I18n.t("job_runs.actions.cancel"),
                    data: {
                      "turbo-method": :patch,
                      "turbo-confirm": I18n.t("job_runs.actions.cancel_confirm"),
                      "turbo-confirm-title": I18n.t("job_runs.actions.cancel_confirm_title"),
                    } do %>
          <%= lucide_icon "x", class: "h-4 w-4" %>
        <% end %>
      <% end %>
    </div>
  </td>
</tr>
```

- [ ] **Step 3: Format ERB files**

```bash
docker compose exec app yarn herb:format
```

Expected: no errors; files reformatted if needed.

- [ ] **Step 4: Commit**

```bash
git add app/views/job_runs/
git commit -m "Add job_runs index view and row partial"
```

---

## Task 9: Sidebar Menu Item + Final Checks

**Files:**
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: Add the Activity log menu item**

In `app/views/layouts/application.html.erb`, add the following line after the Dashboard menu item (line containing `render "shared/menu_item", path: root_path`):

```erb
        <%= render "shared/menu_item", path: job_runs_path, controllers: "job_runs", icon: "clock", title: I18n.t("job_runs.title") %>
```

The sidebar block should read:

```erb
        <%= render "shared/menu_item", path: root_path, controllers: ["dashboard"], icon: "circle-gauge", title: I18n.t("dashboard.title") %>
        <%= render "shared/menu_item", path: job_runs_path, controllers: "job_runs", icon: "clock", title: I18n.t("job_runs.title") %>
        <%= render "shared/menu_item", path: servers_path, controllers: "servers", icon: "server", title: I18n.t("servers.title") %>
        <%= render "shared/menu_item", path: repositories_path, controllers: "repositories", icon: "folders", title: I18n.t("repositories.title") %>
        <%= render "shared/menu_item", path: jobs_path, controllers: "jobs", icon: "arrow-right-left", title: I18n.t("jobs.title") %>
```

- [ ] **Step 2: Format the layout**

```bash
docker compose exec app yarn herb:format
```

Expected: no errors.

- [ ] **Step 3: Run the full relevant test suite**

```bash
docker compose exec app bundle exec rspec spec/models/job_run_spec.rb spec/policies/job_run_policy_spec.rb spec/requests/job_runs_request_spec.rb
```

Expected: all examples pass.

- [ ] **Step 4: Run RuboCop on new/modified Ruby files**

```bash
docker compose exec app bundle exec rubocop app/models/job_run.rb app/policies/job_run_policy.rb app/controllers/job_runs_controller.rb spec/models/job_run_spec.rb spec/policies/job_run_policy_spec.rb spec/requests/job_runs_request_spec.rb spec/factories/job_runs.rb
```

Expected: no offenses.

- [ ] **Step 5: Update PROJECT.md**

In `docs/PROJECT.md`, check off the activity log items under the Dashboard section:

- `[x] Implement activity log page (below dashboard link)`
- `[x] Implement activity log table with the following columns: ...` (all sub-items)

Also mark the `JobRun` model attributes as complete:
- `[x] Job (foreign key)`
- `[x] User (foreign key)`
- `[x] Sequence`
- `[x] Trigger`
- `[x] Status`
- `[x] Started at`
- `[x] Duration`
- `[x] Completed/failed at`
- `[x] Actions`

- [ ] **Step 6: Commit**

```bash
git add app/views/layouts/application.html.erb docs/PROJECT.md
git commit -m "Add Activity log sidebar menu item"
```
