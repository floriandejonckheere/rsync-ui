# Repositories Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add full CRUD management for Repositories (local or remote directories) following the same patterns as the Servers feature.

**Architecture:** Standard Rails CRUD with a model, policy, controller, and views. Repository type (local/remote) is stored as a string enum in `repository_type`. A Stimulus controller (`repository-type`) drives the Basecoat tabs UI, syncing the selected tab to a hidden form field and showing/hiding the server select.

**Tech Stack:** Rails 8, PostgreSQL, ActionPolicy, Hotwire/Turbo, Stimulus, Tailwind CSS + Basecoat UI, RSpec + FactoryBot + Shoulda Matchers, FFaker.

---

## File Map

**Create:**
- `db/migrate/TIMESTAMP_create_repositories.rb` — table definition
- `app/models/repository.rb` — model, enum, validations
- `app/policies/repository_policy.rb` — authorization rules
- `app/controllers/repositories_controller.rb` — CRUD actions
- `app/views/repositories/index.html.erb` — list page
- `app/views/repositories/new.html.erb` — new form page
- `app/views/repositories/edit.html.erb` — edit form page
- `app/views/repositories/_form.html.erb` — shared form partial (tabs)
- `app/views/repositories/_repository.html.erb` — table row partial
- `app/javascript/controllers/repository_type_controller.js` — Stimulus tab controller
- `spec/factories/repositories.rb` — FactoryBot factory
- `spec/models/repository_spec.rb` — model spec
- `spec/policies/repository_policy_spec.rb` — policy spec
- `spec/requests/repositories_request_spec.rb` — request spec

**Modify:**
- `app/models/user.rb` — add `has_many :repositories`
- `config/routes.rb` — add `resources :repositories`
- `app/views/layouts/application.html.erb` — add sidebar menu item
- `app/javascript/controllers/index.js` — register Stimulus controller
- `config/locales/en.yml` — add all i18n strings

---

## Task 1: Factory & Migration

**Files:**
- Create: `spec/factories/repositories.rb`
- Create: `db/migrate/TIMESTAMP_create_repositories.rb`

- [ ] **Step 1: Create the factory**

Create `spec/factories/repositories.rb`:

```ruby
# frozen_string_literal: true

FactoryBot.define do
  factory :repository do
    user

    name { FFaker::Lorem.word.capitalize }
    description { nil }
    repository_type { "local" }
    path { "/data/#{FFaker::Lorem.word}" }
    read_only { false }

    trait :local do
      repository_type { "local" }
      server { nil }
    end

    trait :remote do
      repository_type { "remote" }
      server
    end
  end
end
```

- [ ] **Step 2: Generate the migration**

```bash
docker compose exec app bundle exec rails generate migration CreateRepositories
```

- [ ] **Step 3: Fill in the migration**

Open the generated file in `db/migrate/` and replace its contents with:

```ruby
# frozen_string_literal: true

class CreateRepositories < ActiveRecord::Migration[8.1]
  def change
    create_table :repositories, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.string :repository_type, null: false
      t.string :path, null: false
      t.boolean :read_only, null: false, default: false

      t.references :server, type: :uuid, null: true, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true

      t.timestamps
    end

    add_index :repositories, :repository_type
  end
end
```

- [ ] **Step 4: Confirm before running — ask the user to approve the migration, then run it**

```bash
docker compose exec app bundle exec rails db:migrate
```

Expected output: `== CreateRepositories: migrated`

- [ ] **Step 5: Commit**

```bash
git add spec/factories/repositories.rb db/migrate/*_create_repositories.rb
git commit -m "Add repositories migration"
```

---

## Task 2: Model + User Association (TDD)

**Files:**
- Create: `app/models/repository.rb`
- Modify: `app/models/user.rb`
- Create: `spec/models/repository_spec.rb`

- [ ] **Step 1: Write the failing model spec**

Create `spec/models/repository_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Repository do
  subject(:repository) { build(:repository) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:server).optional }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:path) }

    describe "server required for remote type" do
      context "when type is remote and server is present" do
        subject(:repository) { build(:repository, :remote) }

        it { is_expected.to be_valid }
      end

      context "when type is remote and server is absent" do
        subject(:repository) { build(:repository, repository_type: "remote", server: nil) }

        it { is_expected.not_to be_valid }

        it "adds an error on server" do
          repository.valid?

          expect(repository.errors[:server]).to be_present
        end
      end

      context "when type is local and server is absent" do
        subject(:repository) { build(:repository, :local) }

        it { is_expected.to be_valid }
      end

      context "when type is local and server is present" do
        subject(:repository) { build(:repository, :local, server: build(:server)) }

        it { is_expected.not_to be_valid }

        it "adds an error on server" do
          repository.valid?

          expect(repository.errors[:server]).to be_present
        end
      end
    end
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:repository_type).with_values(local: "local", remote: "remote") }
  end
end
```

- [ ] **Step 2: Run the spec to confirm it fails**

```bash
docker compose exec app bundle exec rspec spec/models/repository_spec.rb
```

Expected: fails with `uninitialized constant Repository`

- [ ] **Step 3: Add i18n error messages for model validations**

Add to `config/locales/en.yml` under the existing `activerecord.errors.models` section:

```yaml
        repository:
          attributes:
            server:
              blank: must be provided for remote repositories
              present: must be absent for local repositories
```

The full `activerecord` block in `en.yml` should now look like:

```yaml
  activerecord:
    errors:
      models:
        server:
          attributes:
            base:
              exclusive_credentials: Exactly one of password or SSH key must be provided.
            ssh_key:
              ssh_key_invalid: is not a valid OpenSSH private key.
              ssh_key_passphrase: must not be protected by a passphrase.
        repository:
          attributes:
            server:
              blank: must be provided for remote repositories
              present: must be absent for local repositories
```

- [ ] **Step 4: Create the model**

Create `app/models/repository.rb`:

```ruby
# frozen_string_literal: true

class Repository < ApplicationRecord
  enum :repository_type, { local: "local", remote: "remote" }, validate: true

  belongs_to :user
  belongs_to :server, optional: true

  validates :name, presence: true
  validates :path, presence: true

  validate :server_presence_for_remote
  validate :server_absence_for_local

  private

  def server_presence_for_remote
    return unless repository_type.present? && remote?

    errors.add(:server, :blank) if server.nil?
  end

  def server_absence_for_local
    return unless repository_type.present? && local?

    errors.add(:server, :present) if server.present?
  end
end
```

- [ ] **Step 5: Add `has_many :repositories` to User**

In `app/models/user.rb`, add after the existing `has_many :servers` line:

```ruby
  has_many :repositories,
           dependent: :destroy
```

- [ ] **Step 6: Annotate models**

```bash
docker compose exec app bundle exec annotaterb models
```

- [ ] **Step 7: Run the model spec to confirm it passes**

```bash
docker compose exec app bundle exec rspec spec/models/repository_spec.rb
```

Expected: all examples pass

- [ ] **Step 8: Commit**

```bash
git add app/models/repository.rb app/models/user.rb spec/models/repository_spec.rb config/locales/en.yml
git commit -m "Add Repository model"
```

---

## Task 3: Policy (TDD)

**Files:**
- Create: `app/policies/repository_policy.rb`
- Create: `spec/policies/repository_policy_spec.rb`

- [ ] **Step 1: Write the failing policy spec**

Create `spec/policies/repository_policy_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe RepositoryPolicy do
  subject(:policy) { described_class.new(record, user:) }

  let(:owner) { build(:user) }
  let(:other_user) { build(:user) }
  let(:admin) { build(:user, :admin) }
  let(:record) { build(:repository, user: owner) }
  let(:user) { owner }

  describe "#index?" do
    it { is_expected.to be_index }
  end

  describe "#create?" do
    it { is_expected.to be_create }
  end

  describe "#edit?" do
    it { is_expected.to be_edit }

    context "when user is another user" do
      let(:user) { other_user }

      it { is_expected.not_to be_edit }
    end

    context "when user is admin" do
      let(:user) { admin }

      it { is_expected.to be_edit }
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

    context "when user is admin" do
      let(:user) { admin }

      it { is_expected.to be_destroy }
    end
  end

  describe ".relation_scope" do
    subject(:scope) { policy.apply_scope(Repository.all, type: :relation) }

    let(:policy) { described_class.new(nil, user: owner) }
    let(:owner) { create(:user) }
    let(:other_user) { create(:user) }

    before do
      create(:repository, user: owner)
      create(:repository, user: other_user)
    end

    it "returns only the user's own repositories" do
      expect(scope.count).to eq(1)
    end

    context "when user is admin" do
      let(:policy) { described_class.new(nil, user: admin) }
      let(:admin) { create(:user, :admin) }

      it "returns all repositories" do
        expect(scope.count).to eq(2)
      end
    end
  end
end
```

- [ ] **Step 2: Run the spec to confirm it fails**

```bash
docker compose exec app bundle exec rspec spec/policies/repository_policy_spec.rb
```

Expected: fails with `uninitialized constant RepositoryPolicy`

- [ ] **Step 3: Create the policy**

Create `app/policies/repository_policy.rb`:

```ruby
# frozen_string_literal: true

class RepositoryPolicy < ApplicationPolicy
  authorize :user

  scope_for :relation do |relation|
    next relation if user.admin?

    relation.where(user:)
  end

  def index?
    user.present?
  end

  def create?
    user.present?
  end

  def edit?
    user.admin? || record.user == user
  end

  def update?
    user.admin? || record.user == user
  end

  def destroy?
    user.admin? || record.user == user
  end
end
```

- [ ] **Step 4: Run the policy spec to confirm it passes**

```bash
docker compose exec app bundle exec rspec spec/policies/repository_policy_spec.rb
```

Expected: all examples pass

- [ ] **Step 5: Commit**

```bash
git add app/policies/repository_policy.rb spec/policies/repository_policy_spec.rb
git commit -m "Add RepositoryPolicy"
```

---

## Task 4: Routes, Controller & I18n

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/repositories_controller.rb`
- Modify: `config/locales/en.yml`

- [ ] **Step 1: Add the route**

In `config/routes.rb`, add `resources :repositories` after `resources :servers`:

```ruby
  resources :configurations, only: [:index, :update]
  resources :servers
  resources :repositories
```

- [ ] **Step 2: Annotate routes**

```bash
docker compose exec app bundle exec annotaterb routes
```

- [ ] **Step 3: Add all remaining i18n strings for repositories**

In `config/locales/en.yml`, add the following block at the top level (same level as `servers:`):

```yaml
  repositories:
    actions:
      delete: Delete repository
      delete_confirm: Are you sure you want to delete this repository? This action cannot be undone.
      delete_confirm_title: Delete repository
      edit: Edit repository
    create:
      success: Repository was successfully created.
    destroy:
      success: Repository was successfully deleted.
    edit:
      title: Edit repository
    form:
      description: Description
      description_placeholder: Optional description for this repository
      details: Details
      local: Local
      local_hint: This repository is stored on the machine running Rsync UI.
      location: Location
      name: Name
      name_placeholder: My repository
      path: Path
      path_placeholder: /data/backups
      read_only: Read-only
      remote: Remote
      server: Server
      server_placeholder: Select a server
      submit_create: Create repository
      submit_update: Update repository
      type: Type
    index:
      empty: No repositories have been configured yet.
      new: New repository
      subtitle: Manage local and remote directories
      title: Repositories
    new:
      subtitle: Add a new repository
      title: New repository
    table:
      name: Name
      path: Path
      read_only: Read-only
      server: Server
      type: Type
    title: Repositories
    types:
      local: Local
      remote: Remote
    update:
      success: Repository was successfully updated.
```

- [ ] **Step 4: Normalize i18n**

```bash
docker compose exec app i18n-tasks normalize
```

- [ ] **Step 5: Create the controller**

Create `app/controllers/repositories_controller.rb`:

```ruby
# frozen_string_literal: true

class RepositoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_repository, only: [:edit, :update, :destroy]
  before_action :set_servers, only: [:new, :edit, :create, :update]

  def index
    @repositories = authorized_scope(Repository.order(:name), type: :relation)

    authorize! :repository
  end

  def new
    @repository = Repository.new(repository_type: "local")

    authorize! @repository
  end

  def edit
    authorize! @repository
  end

  def create
    @repository = current_user.repositories.build(repository_params)

    authorize! @repository

    if @repository.save
      redirect_to repositories_path, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @repository

    if @repository.update(repository_params)
      redirect_to repositories_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @repository

    @repository.destroy!

    redirect_to repositories_path, notice: t(".success"), status: :see_other
  end

  private

  def set_repository
    @repository = Repository.find(params[:id])
  end

  def set_servers
    @servers = current_user.servers.order(:name)
  end

  def repository_params
    permitted = params
      .require(:repository)
      .permit(:name, :description, :repository_type, :server_id, :path, :read_only)

    permitted[:server_id] = nil if permitted[:repository_type] == "local"
    permitted
  end
end
```

- [ ] **Step 6: Commit**

```bash
git add config/routes.rb app/controllers/repositories_controller.rb config/locales/en.yml
git commit -m "Add RepositoriesController"
```

---

## Task 5: Views & Stimulus Controller

**Files:**
- Create: `app/views/repositories/index.html.erb`
- Create: `app/views/repositories/new.html.erb`
- Create: `app/views/repositories/edit.html.erb`
- Create: `app/views/repositories/_form.html.erb`
- Create: `app/views/repositories/_repository.html.erb`
- Create: `app/javascript/controllers/repository_type_controller.js`
- Modify: `app/javascript/controllers/index.js`

- [ ] **Step 1: Create the Stimulus controller**

Create `app/javascript/controllers/repository_type_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel", "input"]

  connect() {
    this.activate(this.inputTarget.value || "local")
  }

  select(event) {
    this.activate(event.currentTarget.dataset.value)
  }

  activate(value) {
    this.inputTarget.value = value

    this.tabTargets.forEach(tab => {
      tab.setAttribute("aria-selected", tab.dataset.value === value ? "true" : "false")
    })

    this.panelTargets.forEach(panel => {
      if (panel.dataset.value === value) {
        panel.removeAttribute("hidden")
      } else {
        panel.setAttribute("hidden", "")
      }
    })
  }
}
```

- [ ] **Step 2: Register the Stimulus controller**

In `app/javascript/controllers/index.js`, add at the end:

```javascript
import RepositoryTypeController from "./repository_type_controller"
application.register("repository-type", RepositoryTypeController)
```

- [ ] **Step 3: Create the index view**

Create `app/views/repositories/index.html.erb`:

```erb
<% content_for :title do %>
  <%= I18n.t("repositories.index.title") %>
<% end %>

<% content_for :subtitle do %>
  <%= I18n.t("repositories.index.subtitle") %>
<% end %>

<% content_for :actions do %>
  <%= link_to new_repository_path, title: I18n.t("repositories.index.new"), class: "btn-icon-outline btn-icon-lg" do %>
    <%= lucide_icon "plus", class: "h-6 w-6" %>
  <% end %>
<% end %>

<% if @repositories.empty? %>
  <div class="card flex flex-col items-center justify-center py-16 gap-4 text-gray-400">
    <%= lucide_icon "folders", class: "h-12 w-12" %>

    <p class="text-lg">
      <%= I18n.t("repositories.index.empty") %>
    </p>
  </div>
<% else %>
  <div class="card p-0 overflow-hidden">
    <table class="w-full text-sm">
      <thead>
        <tr class="border-b border-gray-100 dark:border-gray-700">
          <th class="px-6 py-4 text-left font-medium text-gray-500 dark:text-gray-400">
            <%= I18n.t("repositories.table.name") %>
          </th>

          <th class="px-6 py-4 text-left font-medium text-gray-500 dark:text-gray-400">
            <%= I18n.t("repositories.table.type") %>
          </th>

          <th class="px-6 py-4 text-left font-medium text-gray-500 dark:text-gray-400">
            <%= I18n.t("repositories.table.path") %>
          </th>

          <th class="px-6 py-4 text-left font-medium text-gray-500 dark:text-gray-400">
            <%= I18n.t("repositories.table.server") %>
          </th>

          <th class="px-6 py-4 text-left font-medium text-gray-500 dark:text-gray-400">
            <%= I18n.t("repositories.table.read_only") %>
          </th>

          <th class="px-6 py-4"></th>
        </tr>
      </thead>

      <tbody>
        <% @repositories.each do |repository| %>
          <%= render "repository", repository: %>
        <% end %>
      </tbody>
    </table>
  </div>
<% end %>
```

- [ ] **Step 4: Create the row partial**

Create `app/views/repositories/_repository.html.erb`:

```erb
<tr
  class="
    border-b border-gray-100 dark:border-gray-700 last:border-b-0
    hover:bg-gray-50 dark:hover:bg-gray-700/50
  "
>
  <td class="px-6 py-4">
    <div class="font-medium text-gray-900 dark:text-gray-100">
      <%= repository.name %>
    </div>

    <% if repository.description.present? %>
      <div class="text-xs text-gray-500 dark:text-gray-400 mt-0.5">
        <%= repository.description %>
      </div>
    <% end %>
  </td>

  <td class="px-6 py-4">
    <span
      class="
        inline-flex items-center gap-1 rounded-full px-2 py-1 text-xs
        <%= repository.local? ? "bg-gray-50 dark:bg-gray-700 text-gray-700 dark:text-gray-300" : "bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300" %>
      "
    >
      <%= lucide_icon(repository.local? ? "hard-drive" : "cloud", class: "h-3 w-3") %>
      <%= I18n.t("repositories.types.#{repository.repository_type}") %>
    </span>
  </td>

  <td class="px-6 py-4 font-mono text-gray-600 dark:text-gray-300">
    <%= repository.path %>
  </td>

  <td class="px-6 py-4 text-gray-600 dark:text-gray-300">
    <%= repository.server&.name || "—" %>
  </td>

  <td class="px-6 py-4">
    <% if repository.read_only? %>
      <%= lucide_icon "lock", class: "h-4 w-4 text-amber-500" %>
    <% end %>
  </td>

  <td class="px-6 py-4">
    <div class="flex items-center justify-end gap-2">
      <%= link_to edit_repository_path(repository),
                  class: "btn-icon-outline btn-icon-md",
                  title: I18n.t("repositories.actions.edit") do %>
        <%= lucide_icon "pencil", class: "h-4 w-4" %>
      <% end %>

      <%= link_to repository_path(repository),
                  class: "btn-icon-outline btn-icon-md text-red-600 hover:text-red-700 dark:text-red-400",
                  title: I18n.t("repositories.actions.delete"),
                  data: {
                    "turbo-method": :delete,
                    "turbo-confirm": I18n.t("repositories.actions.delete_confirm"),
                    "turbo-confirm-title": I18n.t("repositories.actions.delete_confirm_title"),
                    "turbo-confirm-destructive": true,
                  } do %>
        <%= lucide_icon "trash-2", class: "h-4 w-4" %>
      <% end %>
    </div>
  </td>
</tr>
```

- [ ] **Step 5: Create the new view**

Create `app/views/repositories/new.html.erb`:

```erb
<% content_for :title do %>
  <%= I18n.t("repositories.new.title") %>
<% end %>

<% content_for :subtitle do %>
  <%= I18n.t("repositories.new.subtitle") %>
<% end %>

<% content_for :back do %>
  <%= render "shared/menu_back", path: repositories_path %>
<% end %>

<%= render "form", repository: @repository %>
```

- [ ] **Step 6: Create the edit view**

Create `app/views/repositories/edit.html.erb`:

```erb
<% content_for :title do %>
  <%= I18n.t("repositories.edit.title") %>
<% end %>

<% content_for :subtitle do %>
  <%= @repository.name %>
<% end %>

<% content_for :back do %>
  <%= render "shared/menu_back", path: repositories_path %>
<% end %>

<%= render "form", repository: @repository %>
```

- [ ] **Step 7: Create the form partial**

Create `app/views/repositories/_form.html.erb`:

```erb
<%= form_with model: repository, id: "repository-form", class: "form" do |f| %>
  <% content_for :actions do %>
    <button
      type="submit"
      form="repository-form"
      class="btn-icon-outline btn-icon-lg"
      title="<%= repository.persisted? ? I18n.t("repositories.form.submit_update") : I18n.t("repositories.form.submit_create") %>"
    >
      <%= lucide_icon "check", class: "h-6 w-6" %>
    </button>
  <% end %>

  <% if repository.errors.any? %>
    <div class="mb-8">
      <%= render "shared/form_messages", model: repository %>
    </div>
  <% end %>

  <div class="grid grid-cols-2 gap-8">
    <div class="flex flex-col gap-8">
      <div class="card">
        <header>
          <h2><%= I18n.t("repositories.form.details") %></h2>
        </header>

        <section>
          <div class="flex flex-col gap-6">
            <div class="field">
              <%= f.label :name, I18n.t("repositories.form.name") %>

              <%= f.text_field :name,
                               placeholder: I18n.t("repositories.form.name_placeholder"),
                               required: true,
                               autocomplete: "off" %>
            </div>

            <div class="field">
              <%= f.label :description, I18n.t("repositories.form.description") %>

              <%= f.text_area :description,
                              placeholder: I18n.t("repositories.form.description_placeholder"),
                              rows: 3,
                              autocomplete: "off" %>
            </div>
          </div>
        </section>
      </div>

      <div class="card">
        <header>
          <h2><%= I18n.t("repositories.form.location") %></h2>
        </header>

        <section>
          <div class="flex flex-col gap-6">
            <div class="field">
              <%= f.label :path, I18n.t("repositories.form.path") %>

              <%= f.text_field :path,
                               placeholder: I18n.t("repositories.form.path_placeholder"),
                               required: true,
                               autocomplete: "off" %>
            </div>

            <div class="field flex-row items-center gap-4">
              <%= f.check_box :read_only %>

              <%= f.label :read_only, I18n.t("repositories.form.read_only") %>
            </div>
          </div>
        </section>
      </div>
    </div>

    <div class="card">
      <header>
        <h2><%= I18n.t("repositories.form.type") %></h2>
      </header>

      <section>
        <div class="tabs w-full" data-controller="repository-type">
          <%= f.hidden_field :repository_type, data: { "repository-type-target": "input" } %>

          <nav role="tablist" aria-orientation="horizontal" class="w-full">
            <button
              type="button"
              role="tab"
              id="repository-type-tab-local"
              aria-controls="repository-type-panel-local"
              aria-selected="false"
              tabindex="0"
              data-repository-type-target="tab"
              data-value="local"
              data-action="click->repository-type#select"
            >
              <%= I18n.t("repositories.form.local") %>
            </button>

            <button
              type="button"
              role="tab"
              id="repository-type-tab-remote"
              aria-controls="repository-type-panel-remote"
              aria-selected="false"
              tabindex="0"
              data-repository-type-target="tab"
              data-value="remote"
              data-action="click->repository-type#select"
            >
              <%= I18n.t("repositories.form.remote") %>
            </button>
          </nav>

          <div
            role="tabpanel"
            id="repository-type-panel-local"
            aria-labelledby="repository-type-tab-local"
            tabindex="-1"
            data-repository-type-target="panel"
            data-value="local"
          >
            <p class="text-sm text-muted-foreground mt-4">
              <%= I18n.t("repositories.form.local_hint") %>
            </p>
          </div>

          <div
            role="tabpanel"
            id="repository-type-panel-remote"
            aria-labelledby="repository-type-tab-remote"
            tabindex="-1"
            data-repository-type-target="panel"
            data-value="remote"
            hidden
          >
            <div class="field mt-4">
              <%= f.label :server_id, I18n.t("repositories.form.server") %>

              <%= f.select :server_id,
                           @servers.map { |s| [s.name, s.id] },
                           { include_blank: I18n.t("repositories.form.server_placeholder") } %>
            </div>
          </div>
        </div>
      </section>
    </div>
  </div>
<% end %>
```

- [ ] **Step 8: Format ERB files**

```bash
docker compose exec app yarn herb:format
```

- [ ] **Step 9: Commit**

```bash
git add app/views/repositories/ app/javascript/controllers/repository_type_controller.js app/javascript/controllers/index.js
git commit -m "Add repositories views and Stimulus controller"
```

---

## Task 6: Request Specs

**Files:**
- Create: `spec/requests/repositories_request_spec.rb`

- [ ] **Step 1: Write the request spec**

Create `spec/requests/repositories_request_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe "Repositories" do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /repositories" do
    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "renders the index page" do
        get repositories_path

        expect(response).to have_http_status(:ok)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get repositories_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /repositories/new" do
    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "renders the new page" do
        get new_repository_path

        expect(response).to have_http_status(:ok)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get new_repository_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /repositories" do
    let(:valid_params) { { repository: { name: "My Repo", path: "/data/backup", repository_type: "local" } } }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "creates the repository for the current user and redirects to the index" do
        expect { post repositories_path, params: valid_params }
          .to change(user.repositories, :count).by(1)

        expect(response).to redirect_to(repositories_path)
      end

      it "displays success message" do
        post repositories_path, params: valid_params

        follow_redirect!

        expect(response.body).to include(I18n.t("repositories.create.success"))
      end

      context "with invalid params" do
        let(:invalid_params) { { repository: { name: "", path: "", repository_type: "local" } } }

        it "renders the new page with errors" do
          post repositories_path, params: invalid_params

          expect(response).to have_http_status(:unprocessable_content)
        end

        it "does not create a repository" do
          expect { post repositories_path, params: invalid_params }
            .not_to change(Repository, :count)
        end
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        post repositories_path, params: valid_params

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /repositories/:id/edit" do
    let(:repository) { create(:repository, user:) }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "renders the edit page" do
        get edit_repository_path(repository)

        expect(response).to have_http_status(:ok)
      end
    end

    context "when repository belongs to another user" do
      let(:repository) { create(:repository, user: other_user) }

      before { sign_in user, scope: :user }

      it "returns forbidden" do
        get edit_repository_path(repository)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get edit_repository_path(repository)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /repositories/:id" do
    let(:repository) { create(:repository, user:) }
    let(:update_params) { { repository: { name: "Updated Repo" } } }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "updates the repository and redirects to the index" do
        patch repository_path(repository), params: update_params

        expect(repository.reload.name).to eq("Updated Repo")
        expect(response).to redirect_to(repositories_path)
      end

      it "displays success message" do
        patch repository_path(repository), params: update_params

        follow_redirect!

        expect(response.body).to include(I18n.t("repositories.update.success"))
      end

      context "with invalid params" do
        let(:invalid_params) { { repository: { name: "", path: "" } } }

        it "renders the edit page with errors" do
          patch repository_path(repository), params: invalid_params

          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    context "when repository belongs to another user" do
      let(:repository) { create(:repository, user: other_user) }

      before { sign_in user, scope: :user }

      it "returns forbidden" do
        patch repository_path(repository), params: update_params

        expect(response).to have_http_status(:forbidden)
      end

      it "does not update the repository" do
        expect do
          patch repository_path(repository), params: update_params
        end.not_to(change { repository.reload.name })
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        patch repository_path(repository), params: update_params

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "DELETE /repositories/:id" do
    let!(:repository) { create(:repository, user:) }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "destroys the repository and redirects to the index" do
        expect do
          delete repository_path(repository)
        end.to change(Repository, :count).by(-1)

        expect(response).to redirect_to(repositories_path)
      end

      it "displays success message" do
        delete repository_path(repository)

        follow_redirect!

        expect(response.body).to include(I18n.t("repositories.destroy.success"))
      end
    end

    context "when repository belongs to another user" do
      let!(:repository) { create(:repository, user: other_user) }

      before { sign_in user, scope: :user }

      it "returns forbidden" do
        delete repository_path(repository)

        expect(response).to have_http_status(:forbidden)
      end

      it "does not destroy the repository" do
        expect do
          delete repository_path(repository)
        end.not_to change(Repository, :count)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        delete repository_path(repository)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
```

- [ ] **Step 2: Run the full spec suite for repositories**

```bash
docker compose exec app bundle exec rspec spec/models/repository_spec.rb spec/policies/repository_policy_spec.rb spec/requests/repositories_request_spec.rb
```

Expected: all examples pass

- [ ] **Step 3: Run RuboCop on all new Ruby files**

```bash
docker compose exec app bundle exec rubocop app/models/repository.rb app/policies/repository_policy.rb app/controllers/repositories_controller.rb spec/factories/repositories.rb spec/models/repository_spec.rb spec/policies/repository_policy_spec.rb spec/requests/repositories_request_spec.rb
```

Expected: no offenses

- [ ] **Step 4: Commit**

```bash
git add spec/requests/repositories_request_spec.rb
git commit -m "Add repositories request specs"
```

---

## Task 7: Sidebar Menu Item & PROJECT.md

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Modify: `docs/PROJECT.md`

- [ ] **Step 1: Add the sidebar menu item**

In `app/views/layouts/application.html.erb`, add after the servers menu item (line 51):

```erb
        <%= render "shared/menu_item", path: repositories_path, controllers: "repositories", icon: "folders", title: I18n.t("repositories.title") %>
```

The two lines together should look like:

```erb
        <%= render "shared/menu_item", path: servers_path, controllers: "servers", icon: "server", title: I18n.t("servers.title") %>
        <%= render "shared/menu_item", path: repositories_path, controllers: "repositories", icon: "folders", title: I18n.t("repositories.title") %>
```

- [ ] **Step 2: Format the ERB layout**

```bash
docker compose exec app yarn herb:format
```

- [ ] **Step 3: Check off completed tasks in PROJECT.md**

In `docs/PROJECT.md`, update the Repositories section:

```markdown
- [x] Implement repositories page
  - [x] Create repository
  - [x] Update repository
  - [x] Destroy repository
```

- [ ] **Step 4: Commit**

```bash
git add app/views/layouts/application.html.erb docs/PROJECT.md
git commit -m "Add repositories sidebar entry"
```
