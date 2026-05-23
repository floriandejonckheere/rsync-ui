# Maintenance Tasks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow admin users to run routine maintenance tasks from the Configuration page.

**Architecture:** A `Task` model stores named maintenance tasks with class_name, last-run metadata, status, and optional configuration dependency. A `TasksController#run` action calls `Tasks::ExecuteService` synchronously and returns a Turbo Stream updating the task's inline status. A `task-run` Stimulus controller manages per-row loading state.

**Tech Stack:** Rails 8.0, PostgreSQL, Hotwire (Turbo + Stimulus), ActionPolicy, RSpec + FactoryBot, Tailwind CSS 4.x + Basecoat UI, Lucide Icons.

---

## File Map

**Create:**
- `db/migrate/20260523132833_create_tasks.rb` — migration for `tasks` table
- `app/models/task.rb` — Task model with enum, validations, associations
- `spec/factories/tasks.rb` — FactoryBot factory
- `spec/models/task_spec.rb` — model validations, associations, scopes
- `app/policies/task_policy.rb` — admin-only index? and run? actions
- `spec/policies/task_policy_spec.rb` — policy spec
- `app/controllers/tasks_controller.rb` — index + run actions
- `spec/requests/tasks_request_spec.rb` — authentication, authorization, actions
- `app/services/tasks/execute_service.rb` — constantize class_name, call .call, update task status
- `app/services/tasks/ssh_config_service.rb` — wraps Servers::SSHConfigService.call
- `spec/services/tasks/execute_service_spec.rb` — happy path, error path
- `app/javascript/controllers/task_run_controller.js` — loading state for run button
- `app/views/tasks/_task.html.erb` — task row partial (name, description, status, run button)
- `app/views/tasks/index.html.erb` — not needed; tasks rendered inline on configurations page
- `config/locales/tasks/en.yml` — all user-facing strings
- `db/seeds/02_tasks.rb` — seeding tasks
- `db/seeds/02_tasks.csv` — seed data with sync_ssh_config task

**Modify:**
- `config/routes.rb` — add `resources :tasks, only: [:index]` with `member { post :run }`
- `app/views/configurations/index.html.erb` — add Maintenance card below configuration categories
- `app/javascript/controllers/index.js` — Stimulus auto-discovers (check if manual registration needed)

---

## Task 1: Migration, Model, Factory, and Model Spec

**Files:**
- Create: `db/migrate/20260523132833_create_tasks.rb`
- Create: `app/models/task.rb`
- Create: `spec/factories/tasks.rb`
- Create: `spec/models/task_spec.rb`

- [ ] **Step 1: Write the failing model spec**

```ruby
# spec/models/task_spec.rb
# frozen_string_literal: true

RSpec.describe Task do
  subject(:task) { build(:task) }

  describe "associations" do
    it { is_expected.to belong_to(:last_run_by).class_name("User").optional }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:class_name) }
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:status)
        .with_values(running: "running", completed: "completed", failed: "failed")
        .backed_by_column_of_type(:string)
    }
  end
end
```

- [ ] **Step 2: Run the spec to confirm it fails**

```bash
docker compose exec app bundle exec rspec spec/models/task_spec.rb
```

Expected: FAIL with "uninitialized constant Task"

- [ ] **Step 3: Write the migration**

```ruby
# db/migrate/20260523132833_create_tasks.rb
# frozen_string_literal: true

class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks, id: :uuid do |t|
      t.string :name, null: false
      t.string :class_name, null: false
      t.datetime :last_run_at
      t.references :last_run_by, type: :uuid, foreign_key: { to_table: :users, dependent: :nullify }, null: true
      t.string :status
      t.string :configuration
      t.string :error_class
      t.text :error_message

      t.timestamps
    end
  end
end
```

- [ ] **Step 4: Prompt the user to run the migration**

This step requires human confirmation before running:
```
docker compose exec app bundle exec rails db:migrate
```

- [ ] **Step 5: Write the Task model**

```ruby
# app/models/task.rb
# frozen_string_literal: true

class Task < ApplicationRecord
  belongs_to :last_run_by,
             class_name: "User",
             foreign_key: :last_run_by,
             optional: true

  validates :name, presence: true
  validates :class_name, presence: true

  enum :status, {
    running: "running",
    completed: "completed",
    failed: "failed",
  }, validate: { allow_nil: true }

  def configuration_satisfied?
    return true if configuration.blank?

    Configuration.get(configuration).present?
  end
end

# == Schema Information
#
# Table name: tasks
#
#  id              :uuid             not null, primary key
#  class_name      :string           not null
#  configuration   :string
#  error_class     :string
#  error_message   :text
#  last_run_at     :datetime
#  name            :string           not null
#  status          :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  last_run_by     :uuid
#
# Foreign Keys
#
#  fk_rails_...  (last_run_by => users.id)
#
```

- [ ] **Step 6: Write the factory**

```ruby
# spec/factories/tasks.rb
# frozen_string_literal: true

FactoryBot.define do
  factory :task do
    name { "sync_ssh_config" }
    class_name { "Tasks::SSHConfigService" }
    status { nil }
    configuration { nil }

    trait :completed do
      status { "completed" }
      last_run_at { 1.hour.ago }
    end

    trait :failed do
      status { "failed" }
      last_run_at { 1.hour.ago }
      error_class { "StandardError" }
      error_message { "Something went wrong" }
    end
  end
end
```

- [ ] **Step 7: Run the model spec to verify it passes**

```bash
docker compose exec app bundle exec rspec spec/models/task_spec.rb
```

Expected: All examples pass.

- [ ] **Step 8: Annotate models**

```bash
docker compose exec app bundle exec annotaterb models
```

- [ ] **Step 9: Run Rubocop on new files**

```bash
docker compose exec app bundle exec rubocop db/migrate/20260523132833_create_tasks.rb app/models/task.rb spec/factories/tasks.rb spec/models/task_spec.rb
```

Expected: No offenses.

- [ ] **Step 10: Commit**

```bash
git add db/migrate/20260523132833_create_tasks.rb app/models/task.rb spec/factories/tasks.rb spec/models/task_spec.rb db/schema.rb
git commit -m "Add Task model with status enum and user association"
```

---

## Task 2: Routes, Controller, Policy, and Specs

**Files:**
- Modify: `config/routes.rb`
- Create: `app/policies/task_policy.rb`
- Create: `spec/policies/task_policy_spec.rb`
- Create: `app/controllers/tasks_controller.rb`
- Create: `spec/requests/tasks_request_spec.rb`

- [ ] **Step 1: Write the failing policy spec**

```ruby
# spec/policies/task_policy_spec.rb
# frozen_string_literal: true

RSpec.describe TaskPolicy do
  subject(:policy) { described_class.new(record, user:) }

  let(:record) { build(:task) }
  let(:user) { build(:user) }

  describe "#index?" do
    it { is_expected.not_to be_index }

    context "when the user is admin" do
      let(:user) { build(:user, :admin) }

      it { is_expected.to be_index }
    end
  end

  describe "#run?" do
    it { is_expected.not_to be_run }

    context "when the user is admin" do
      let(:user) { build(:user, :admin) }

      it { is_expected.to be_run }
    end
  end

  describe ".relation_scope" do
    subject(:scope) { policy.apply_scope(Task.all, type: :relation) }

    let(:policy) { described_class.new(nil, user:) }

    before { create(:task) }

    it { is_expected.to be_empty }

    context "when the user is admin" do
      let(:user) { build(:user, :admin) }

      it { is_expected.not_to be_empty }
    end
  end
end
```

- [ ] **Step 2: Run the policy spec to confirm it fails**

```bash
docker compose exec app bundle exec rspec spec/policies/task_policy_spec.rb
```

Expected: FAIL with "uninitialized constant TaskPolicy"

- [ ] **Step 3: Write the policy**

```ruby
# app/policies/task_policy.rb
# frozen_string_literal: true

class TaskPolicy < ApplicationPolicy
  authorize :user

  scope_for :relation do |relation|
    next relation if user.admin?

    relation.none
  end

  def index?
    user&.admin?
  end

  def run?
    user&.admin?
  end
end
```

- [ ] **Step 4: Add routes**

Open `config/routes.rb` and add after the `resources :configurations` line:

```ruby
resources :tasks, only: [:index] do
  member do
    post :run
  end
end
```

- [ ] **Step 5: Write the failing request spec**

```ruby
# spec/requests/tasks_request_spec.rb
# frozen_string_literal: true

RSpec.describe "Tasks" do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:task) { create(:task) }

  describe "GET /tasks" do
    context "when user is an admin" do
      before { sign_in admin, scope: :user }

      it "renders the index page" do
        get tasks_path

        expect(response).to have_http_status(:ok)
      end
    end

    context "when user is not an admin" do
      before { sign_in user, scope: :user }

      it "returns forbidden" do
        get tasks_path

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        get tasks_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /tasks/:id/run" do
    context "when user is an admin" do
      before { sign_in admin, scope: :user }

      it "returns a Turbo Stream response on success" do
        allow(Tasks::ExecuteService).to receive(:call).and_return(success: true)

        post run_task_path(task), headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end

      it "returns a Turbo Stream response on failure" do
        allow(Tasks::ExecuteService).to receive(:call).and_return(success: false, message: "Something failed")

        post run_task_path(task), headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end
    end

    context "when user is not an admin" do
      before { sign_in user, scope: :user }

      it "returns forbidden" do
        post run_task_path(task), headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        post run_task_path(task)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
```

- [ ] **Step 6: Write the controller**

```ruby
# app/controllers/tasks_controller.rb
# frozen_string_literal: true

# == Route Map
#
#         run_task POST /tasks/:id/run(.:format) tasks#run
#            tasks GET  /tasks(.:format)         tasks#index

class TasksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_task, only: [:run]

  def index
    @tasks = authorized_scope(Task.order(:name), type: :relation)

    authorize! :task
  end

  def run
    authorize! @task, to: :run?

    result = Tasks::ExecuteService.call(@task, user: current_user)

    render turbo_stream: turbo_stream.replace(
      dom_id(@task, :status),
      partial: "tasks/task_status",
      locals: { task: @task.reload, result: },
    )
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end
end
```

- [ ] **Step 7: Run the policy and request specs to verify they pass**

```bash
docker compose exec app bundle exec rspec spec/policies/task_policy_spec.rb spec/requests/tasks_request_spec.rb
```

Expected: All examples pass (the request spec will pass once services are stubbed).

- [ ] **Step 8: Annotate routes**

```bash
docker compose exec app bundle exec annotaterb routes
```

- [ ] **Step 9: Run Rubocop**

```bash
docker compose exec app bundle exec rubocop app/policies/task_policy.rb app/controllers/tasks_controller.rb spec/policies/task_policy_spec.rb spec/requests/tasks_request_spec.rb config/routes.rb
```

Expected: No offenses.

- [ ] **Step 10: Commit**

```bash
git add config/routes.rb app/policies/task_policy.rb app/controllers/tasks_controller.rb spec/policies/task_policy_spec.rb spec/requests/tasks_request_spec.rb
git commit -m "Add TasksController and TaskPolicy with index and run actions"
```

---

## Task 3: Services and Service Specs

**Files:**
- Create: `app/services/tasks/execute_service.rb`
- Create: `app/services/tasks/ssh_config_service.rb`
- Create: `spec/services/tasks/execute_service_spec.rb`

- [ ] **Step 1: Write the failing execute service spec**

```ruby
# spec/services/tasks/execute_service_spec.rb
# frozen_string_literal: true

RSpec.describe Tasks::ExecuteService do
  subject(:service) { described_class.new(task, user:) }

  let(:task) { create(:task, class_name: "Tasks::SSHConfigService") }
  let(:user) { create(:user, :admin) }

  describe "#call" do
    context "when task executes successfully" do
      before do
        allow(Tasks::SSHConfigService).to receive(:call)
      end

      it "returns success" do
        expect(service.call).to eq(success: true)
      end

      it "updates task status to completed" do
        service.call

        expect(task.reload.status).to eq("completed")
      end

      it "records last_run_at and last_run_by" do
        service.call

        task.reload

        expect(task.last_run_at).to be_within(5.seconds).of(Time.zone.now)
        expect(task.last_run_by).to eq(user.id)
      end

      it "clears error fields" do
        task.update!(status: "failed", error_class: "StandardError", error_message: "old error")

        service.call

        task.reload

        expect(task.error_class).to be_nil
        expect(task.error_message).to be_nil
      end
    end

    context "when task raises an error" do
      before do
        allow(Tasks::SSHConfigService)
          .to receive(:call)
          .and_raise(StandardError, "SSH config failed")
      end

      it "returns failure with message" do
        expect(service.call).to eq(success: false, message: "StandardError: SSH config failed")
      end

      it "updates task status to failed" do
        service.call

        expect(task.reload.status).to eq("failed")
      end

      it "records error class and message" do
        service.call

        task.reload

        expect(task.error_class).to eq("StandardError")
        expect(task.error_message).to eq("SSH config failed")
      end

      it "records last_run_at and last_run_by even on failure" do
        service.call

        task.reload

        expect(task.last_run_at).to be_within(5.seconds).of(Time.zone.now)
        expect(task.last_run_by).to eq(user.id)
      end
    end
  end
end
```

- [ ] **Step 2: Run the spec to confirm it fails**

```bash
docker compose exec app bundle exec rspec spec/services/tasks/execute_service_spec.rb
```

Expected: FAIL with "uninitialized constant Tasks::ExecuteService"

- [ ] **Step 3: Write the execute service**

```ruby
# app/services/tasks/execute_service.rb
# frozen_string_literal: true

module Tasks
  class ExecuteService < ApplicationService
    attr_reader :task, :user

    def initialize(task, user:)
      super()

      @task = task
      @user = user
    end

    def call
      task.update!(
        status: :running,
        last_run_at: Time.zone.now,
        last_run_by: user.id,
        error_class: nil,
        error_message: nil,
      )

      task.class_name.constantize.call

      task.update!(status: :completed)

      { success: true }
    rescue => e
      task.update!(
        status: :failed,
        error_class: e.class.name,
        error_message: e.message,
      )

      { success: false, message: "#{e.class}: #{e.message}" }
    end
  end
end
```

- [ ] **Step 4: Write the SSH config service**

```ruby
# app/services/tasks/ssh_config_service.rb
# frozen_string_literal: true

module Tasks
  class SSHConfigService < ApplicationService
    def call
      Servers::SSHConfigService.call
    end
  end
end
```

- [ ] **Step 5: Run the execute service spec to verify it passes**

```bash
docker compose exec app bundle exec rspec spec/services/tasks/execute_service_spec.rb
```

Expected: All examples pass.

- [ ] **Step 6: Run Rubocop**

```bash
docker compose exec app bundle exec rubocop app/services/tasks/execute_service.rb app/services/tasks/ssh_config_service.rb spec/services/tasks/execute_service_spec.rb
```

Expected: No offenses.

- [ ] **Step 7: Commit**

```bash
git add app/services/tasks/execute_service.rb app/services/tasks/ssh_config_service.rb spec/services/tasks/execute_service_spec.rb
git commit -m "Add Tasks::ExecuteService and Tasks::SSHConfigService"
```

---

## Task 4: Views, Stimulus Controller, and i18n

**Files:**
- Create: `config/locales/tasks/en.yml`
- Create: `app/views/tasks/_task.html.erb`
- Create: `app/views/tasks/_task_status.html.erb`
- Create: `app/javascript/controllers/task_run_controller.js`
- Modify: `app/views/configurations/index.html.erb`

- [ ] **Step 1: Create the locale file**

```yaml
# config/locales/tasks/en.yml
---
en:
  tasks:
    index:
      run: Run
      run_tooltip: Run task
      subtitle: Run routine maintenance tasks
      title: Maintenance
    names:
      sync_ssh_config:
        description: Sync SSH config file with the database
        title: Sync SSH config
    run:
      failure: Task failed
      success: Task completed successfully
```

- [ ] **Step 2: Normalize i18n files**

```bash
docker compose exec app bundle exec i18n-tasks normalize
```

- [ ] **Step 3: Create the task status partial**

This partial is rendered by the turbo stream to update the inline status icon.

```erb
<%# app/views/tasks/_task_status.html.erb %>
<%= turbo_frame_tag dom_id(task, :status) do %>
  <% if task.completed? %>
    <%= lucide_icon "circle-check",
                    class: "h-5 w-5 text-green-500" %>
  <% elsif task.failed? %>
    <%= lucide_icon "circle-x",
                    class: "h-5 w-5 text-red-500",
                    data: { tooltip: task.error_message } %>
  <% end %>
<% end %>
```

- [ ] **Step 4: Create the task row partial**

```erb
<%# app/views/tasks/_task.html.erb %>
<% disabled = !task.configuration_satisfied? %>

<div class="py-4 border-b border-gray-100 dark:border-gray-700 last:border-b-0 <%= 'opacity-50' if disabled %>">
  <div class="flex items-center justify-between">
    <div class="flex flex-col gap-1">
      <span class="text-lg font-semibold text-gray-700 dark:text-gray-200">
        <%= I18n.t("tasks.names.#{task.name}.title") %>
      </span>

      <span class="text-sm text-gray-400 dark:text-gray-500">
        <%= I18n.t("tasks.names.#{task.name}.description") %>
      </span>
    </div>

    <div class="flex items-center gap-3">
      <%= render "tasks/task_status", task: %>

      <%= form_with url: run_task_path(task),
                    method: :post,
                    data: {
                      turbo_stream: true,
                      controller: "task-run",
                    } do |f| %>
        <button
          type="submit"
          class="btn-outline btn-sm"
          data-task-run-target="button"
          data-tooltip="<%= I18n.t("tasks.index.run_tooltip") %>"
          <%= "disabled" if disabled %>
        >
          <%= lucide_icon "play",
                          class: "h-4 w-4",
                          data: { "task-run-target": "icon" } %>

          <%= lucide_icon "loader-circle",
                          class: "h-4 w-4 hidden animate-spin",
                          data: { "task-run-target": "spinner" } %>

          <%= I18n.t("tasks.index.run") %>
        </button>
      <% end %>
    </div>
  </div>
</div>
```

- [ ] **Step 5: Create the Stimulus controller**

```javascript
// app/javascript/controllers/task_run_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "icon", "spinner"]

  connect() {
    this.element.addEventListener("turbo:submit-start", () => this.#setLoading(true))
    this.element.addEventListener("turbo:submit-end", () => this.#setLoading(false))
  }

  #setLoading(loading) {
    this.buttonTarget.disabled = loading
    this.iconTarget.classList.toggle("hidden", loading)
    this.spinnerTarget.classList.toggle("hidden", !loading)
  }
}
```

- [ ] **Step 6: Register the Stimulus controller in index.js if needed**

Check `app/javascript/controllers/index.js`. If it uses `eagerLoadControllersFrom` or similar auto-discovery, no change is needed. If controllers are registered manually, add:

```javascript
import TaskRunController from "./task_run_controller"
application.register("task-run", TaskRunController)
```

Check with:
```bash
cat /Users/florian/Code/rsync-ui/app/javascript/controllers/index.js
```

- [ ] **Step 7: Add the Maintenance card to the configurations index**

Open `app/views/configurations/index.html.erb` and add a Maintenance card below the configuration categories loop. Add after the closing `<% end %>` of the `@configurations.group_by` each loop:

```erb
<details id="category-maintenance" class="card group py-0">
  <summary
    class="
      flex items-center justify-between w-full px-8 py-8 cursor-pointer
      list-none
    "
  >
    <div class="flex flex-col gap-1">
      <h2 class="text-lg font-semibold">
        <%= I18n.t("tasks.index.title") %>
      </h2>

      <div class="text-sm text-muted-foreground">
        <%= I18n.t("tasks.index.subtitle") %>
      </div>
    </div>

    <%= lucide_icon "chevron-down",
                    class: "h-5 w-5 transition-transform duration-200 group-open:rotate-180" %>
  </summary>

  <div class="px-8 pb-8">
    <% @tasks.each do |task| %>
      <%= render "tasks/task", task: %>
    <% end %>
  </div>
</details>
```

- [ ] **Step 8: Update ConfigurationsController#index to load tasks**

Open `app/controllers/configurations_controller.rb` and add `@tasks` to the index action:

```ruby
def index
  @configurations = authorized_scope(Configuration.order(:key), type: :relation)
  @tasks = authorized_scope(Task.order(:name), type: :relation, with: TaskPolicy)

  authorize! :configuration
end
```

Wait — the authorized_scope already scopes by the record type. For tasks on the configuration page, the safest approach that avoids needing a second authorize! call is to load tasks directly since the index? on TaskPolicy is also admin-only (same as ConfigurationPolicy). Adjust to:

```ruby
def index
  @configurations = authorized_scope(Configuration.order(:key), type: :relation)
  @tasks = Task.order(:name) if current_user&.admin?

  authorize! :configuration
end
```

- [ ] **Step 9: Format ERB files**

```bash
docker compose exec app yarn herb:format
```

- [ ] **Step 10: Run the full request spec to verify views render**

```bash
docker compose exec app bundle exec rspec spec/requests/tasks_request_spec.rb spec/requests/configurations_request_spec.rb
```

Expected: All examples pass.

- [ ] **Step 11: Run Rubocop on modified Ruby files**

```bash
docker compose exec app bundle exec rubocop app/controllers/configurations_controller.rb
```

- [ ] **Step 12: Commit**

```bash
git add config/locales/tasks/ app/views/tasks/ app/javascript/controllers/task_run_controller.js app/views/configurations/index.html.erb app/controllers/configurations_controller.rb
git commit -m "Add Maintenance card to Configuration page with task run UI"
```

---

## Task 5: Seeds

**Files:**
- Create: `db/seeds/02_tasks.rb`
- Create: `db/seeds/02_tasks.csv`

- [ ] **Step 1: Create the seed CSV**

```csv
# db/seeds/02_tasks.csv
name,class_name,configuration
sync_ssh_config,Tasks::SSHConfigService,
```

- [ ] **Step 2: Create the seed file**

```ruby
# db/seeds/02_tasks.rb
# frozen_string_literal: true

puts "Seeding tasks..."

Tasks::ImportService.call(path: Rails.root.join("db/seeds"))

puts "  Done."
```

- [ ] **Step 3: Create the import service**

```ruby
# app/services/tasks/import_service.rb
# frozen_string_literal: true

module Tasks
  class ImportService < ::ImportService
    private

    def csv_filename
      "02_tasks.csv"
    end

    def import(row)
      Task
        .create_with(
          class_name: row["class_name"],
          configuration: row["configuration"].presence,
        )
        .find_or_create_by!(name: row["name"])
    end
  end
end
```

- [ ] **Step 4: Run the seeds in development to verify**

```bash
docker compose exec app bundle exec rails db:seed
```

Expected: Seeds run without errors, task record created.

- [ ] **Step 5: Run Rubocop**

```bash
docker compose exec app bundle exec rubocop db/seeds/02_tasks.rb app/services/tasks/import_service.rb
```

- [ ] **Step 6: Commit**

```bash
git add db/seeds/02_tasks.rb db/seeds/02_tasks.csv app/services/tasks/import_service.rb
git commit -m "Add seed data for maintenance tasks"
```

---

## Task 6: Final Verification

- [ ] **Step 1: Run the full test suite for all new files**

```bash
docker compose exec app bundle exec rspec spec/models/task_spec.rb spec/factories/tasks.rb spec/policies/task_policy_spec.rb spec/requests/tasks_request_spec.rb spec/services/tasks/execute_service_spec.rb
```

Expected: All examples pass.

- [ ] **Step 2: Run Rubocop on all modified files**

```bash
docker compose exec app bundle exec rubocop app/models/task.rb app/policies/task_policy.rb app/controllers/tasks_controller.rb app/controllers/configurations_controller.rb app/services/tasks/ spec/
```

Expected: No offenses.

- [ ] **Step 3: Format all ERB files**

```bash
docker compose exec app yarn herb:format
```

- [ ] **Step 4: Check i18n**

```bash
docker compose exec app bundle exec i18n-tasks normalize
docker compose exec app bundle exec i18n-tasks missing
```

Expected: No missing keys.

- [ ] **Step 5: Update PROJECT.md**

Mark the Maintenance feature as complete in `docs/PROJECT.md`.

---

## Spec Coverage Notes

- **Task model**: validations (name, class_name presence), enum (status with string backing, nil allowed), belongs_to association (optional)
- **TaskPolicy**: index? and run? admin-only, scope returns empty for non-admin
- **TasksController**: index requires admin, run requires admin, authentication redirects, turbo stream response format
- **Tasks::ExecuteService**: happy path updates status to completed + clears errors, failure path updates status to failed + records error, last_run_at and last_run_by always set
- **Tasks::SSHConfigService**: calls Servers::SSHConfigService (can be a quick unit test or skipped since it's a thin wrapper)

## Caveats / Edge Cases

1. **`Servers::SyncSSHConfigService` vs `Servers::SSHConfigService`**: The spec references `Servers::SyncSSHConfigService.call` but only `Servers::SSHConfigService` exists in the codebase. The plan uses `Servers::SSHConfigService` directly.

2. **`configuration` column type**: The `configuration` column stores a configuration key string (e.g., `"ssh.enabled"`). The `configuration_satisfied?` method uses `Configuration.get` which handles nil returns when dependencies are not met.

3. **Authorization on configurations#index for tasks**: The `@tasks` load uses a direct admin check to avoid double `authorize!` while still being secure — the page itself is already admin-only via `ConfigurationPolicy#index?`.

4. **Inline run button**: The run form posts to `run_task_path`, returns a turbo stream replacing `dom_id(task, :status)`. The Stimulus controller only manages button loading state. The status icon persists in DB between page loads.
