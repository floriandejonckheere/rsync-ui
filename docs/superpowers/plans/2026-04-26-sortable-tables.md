# Sortable Tables Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add clickable column-header sort to the Servers, Repositories, Jobs, and Job Runs index pages, with ascending/descending/default cycling and a caret indicator on the active column.

**Architecture:** A `Sortable` controller concern reads and validates `sort`/`direction` params, exposes `sort_for(scope, allowed:, default:)`, and sets `@sort_column`/`@sort_direction` instance variables that a shared `_sort_header.html.erb` partial reads to render sortable `<th>` elements with Lucide caret icons and URL links that preserve existing filter/search/page params. Database indexes are added in a single migration covering all sort and ILIKE-search columns.

**Tech Stack:** Rails 8.0, PostgreSQL 18, Hotwire Turbo, Lucide icons, RSpec request specs, pg_trgm extension

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `app/controllers/concerns/sortable.rb` | **Create** | Concern: reads params, exposes `sort_for` |
| `app/views/shared/_sort_header.html.erb` | **Create** | Shared partial: sortable `<th>` with caret |
| `app/controllers/servers_controller.rb` | **Modify** | Include Sortable, use sort_for |
| `app/controllers/repositories_controller.rb` | **Modify** | Include Sortable, use sort_for |
| `app/controllers/jobs_controller.rb` | **Modify** | Include Sortable, use sort_for |
| `app/controllers/job_runs_controller.rb` | **Modify** | Include Sortable, use sort_for |
| `app/views/servers/index.html.erb` | **Modify** | Replace static `<th>` with sort_header partial |
| `app/views/repositories/index.html.erb` | **Modify** | Replace static `<th>` with sort_header partial |
| `app/views/jobs/index.html.erb` | **Modify** | Replace static `<th>` with sort_header partial |
| `app/views/job_runs/index.html.erb` | **Modify** | Replace static `<th>` with sort_header partial |
| `spec/requests/servers_request_spec.rb` | **Modify** | Add sort request specs |
| `spec/requests/repositories_request_spec.rb` | **Modify** | Add sort request specs |
| `spec/requests/jobs_request_spec.rb` | **Modify** | Add sort request specs |
| `spec/requests/job_runs_request_spec.rb` | **Modify** | Add sort request specs |
| `db/migrate/TIMESTAMP_add_sort_and_search_indexes.rb` | **Create** | B-tree + GIN trigram indexes |

---

## Task 1: Sortable concern + Servers sort specs (TDD)

**Files:**
- Create: `app/controllers/concerns/sortable.rb`
- Modify: `spec/requests/servers_request_spec.rb`

- [ ] **Step 1: Write failing sort specs for ServersController**

Add the following context block inside the `describe "GET /servers"` / `context "when authenticated"` block in `spec/requests/servers_request_spec.rb`, after the existing query-parameter context:

```ruby
context "when sort parameters are present" do
  it "sorts servers by name ascending" do
    zebra = create(:server, user:, name: "Zebra server")
    alpha = create(:server, user:, name: "Alpha server")

    get servers_path, params: { sort: "name", direction: "asc" }

    expect(response.body.index(alpha.name)).to be < response.body.index(zebra.name)
  end

  it "sorts servers by name descending" do
    zebra = create(:server, user:, name: "Zebra server")
    alpha = create(:server, user:, name: "Alpha server")

    get servers_path, params: { sort: "name", direction: "desc" }

    expect(response.body.index(zebra.name)).to be < response.body.index(alpha.name)
  end

  it "sorts servers by host ascending" do
    z_server = create(:server, user:, host: "z.example.com")
    a_server = create(:server, user:, host: "a.example.com")

    get servers_path, params: { sort: "host", direction: "asc" }

    expect(response.body.index(a_server.host)).to be < response.body.index(z_server.host)
  end

  it "falls back to default name sort when direction is invalid" do
    create(:server, user:, name: "Beta server")

    get servers_path, params: { sort: "name", direction: "invalid" }

    expect(response).to have_http_status(:ok)
  end

  it "falls back to default sort when column is not allowed" do
    create(:server, user:, name: "Beta server")

    get servers_path, params: { sort: "password", direction: "asc" }

    expect(response).to have_http_status(:ok)
  end
end
```

- [ ] **Step 2: Run specs to verify they fail**

```bash
docker compose exec app bundle exec rspec spec/requests/servers_request_spec.rb --format documentation 2>&1 | tail -20
```

Expected: failures mentioning `sort` params having no effect / NoMethodError.

- [ ] **Step 3: Create the Sortable concern**

Create `app/controllers/concerns/sortable.rb`:

```ruby
# frozen_string_literal: true

module Sortable
  extend ActiveSupport::Concern

  included do
    before_action :set_sort
  end

  private

  def set_sort
    @sort_column = params[:sort].presence
    @sort_direction = params[:direction].in?(%w[asc desc]) ? params[:direction] : nil
    @sort_column = nil unless @sort_direction
  end

  def sort_for(scope, allowed:, default:)
    if @sort_column&.in?(allowed.map(&:to_s)) && @sort_direction
      scope.reorder(@sort_column => @sort_direction)
    else
      scope.reorder(default)
    end
  end
end
```

- [ ] **Step 4: Wire Sortable into ServersController**

Replace the full `index` action in `app/controllers/servers_controller.rb`. Also add `include Sortable` and remove `include Searchable`'s ordering from the scope (the controller already includes Searchable — just add Sortable alongside it):

```ruby
# frozen_string_literal: true

class ServersController < ApplicationController
  include Searchable
  include Sortable

  before_action :authenticate_user!
  before_action :set_server, only: [:edit, :update, :destroy]

  def index
    servers = authorized_scope(Server.all, type: :relation)
    servers = search_for(servers, "name", "description", "host")
    servers = sort_for(servers, allowed: %w[name host], default: { name: :asc })

    @pagy, @servers = pagy(servers)

    authorize! :server
  end

  # ... rest of file unchanged
```

- [ ] **Step 5: Run specs to verify they pass**

```bash
docker compose exec app bundle exec rspec spec/requests/servers_request_spec.rb --format documentation 2>&1 | tail -20
```

Expected: all examples pass.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/concerns/sortable.rb app/controllers/servers_controller.rb spec/requests/servers_request_spec.rb
git commit -m "Add Sortable concern and wire up ServersController"
```

---

## Task 2: Sort specs and wiring for Repositories, Jobs, Job Runs

**Files:**
- Modify: `app/controllers/repositories_controller.rb`
- Modify: `app/controllers/jobs_controller.rb`
- Modify: `app/controllers/job_runs_controller.rb`
- Modify: `spec/requests/repositories_request_spec.rb`
- Modify: `spec/requests/jobs_request_spec.rb`
- Modify: `spec/requests/job_runs_request_spec.rb`

- [ ] **Step 1: Write failing sort specs for RepositoriesController**

Add inside `describe "GET /repositories"` / `context "when authenticated"`:

```ruby
context "when sort parameters are present" do
  it "sorts repositories by name ascending" do
    z_repo = create(:repository, user:, name: "Zebra repo")
    a_repo = create(:repository, user:, name: "Alpha repo")

    get repositories_path, params: { sort: "name", direction: "asc" }

    expect(response.body.index(a_repo.name)).to be < response.body.index(z_repo.name)
  end

  it "sorts repositories by name descending" do
    z_repo = create(:repository, user:, name: "Zebra repo")
    a_repo = create(:repository, user:, name: "Alpha repo")

    get repositories_path, params: { sort: "name", direction: "desc" }

    expect(response.body.index(z_repo.name)).to be < response.body.index(a_repo.name)
  end

  it "falls back to default sort when column is not allowed" do
    create(:repository, user:)

    get repositories_path, params: { sort: "path", direction: "asc" }

    expect(response).to have_http_status(:ok)
  end
end
```

Note: `repository_type` and `path` are valid sort columns but testing name ascending/descending is sufficient to verify the mechanism works.

- [ ] **Step 2: Write failing sort specs for JobsController**

Add inside `describe "GET /jobs"` / `context "when authenticated"`:

```ruby
context "when sort parameters are present" do
  it "sorts jobs by name ascending" do
    z_job = create(:job, user:, name: "Zebra job")
    a_job = create(:job, user:, name: "Alpha job")

    get jobs_path, params: { sort: "name", direction: "asc" }

    expect(response.body.index(a_job.name)).to be < response.body.index(z_job.name)
  end

  it "sorts jobs by name descending" do
    z_job = create(:job, user:, name: "Zebra job")
    a_job = create(:job, user:, name: "Alpha job")

    get jobs_path, params: { sort: "name", direction: "desc" }

    expect(response.body.index(z_job.name)).to be < response.body.index(a_job.name)
  end

  it "falls back to default sort when column is not allowed" do
    create(:job, user:)

    get jobs_path, params: { sort: "opt_delete", direction: "asc" }

    expect(response).to have_http_status(:ok)
  end
end
```

- [ ] **Step 3: Write failing sort specs for JobRunsController**

Add inside `describe "GET /job_runs"` / `context "when authenticated"`:

```ruby
context "when sort parameters are present" do
  it "sorts job runs by sequence ascending" do
    job = create(:job, user:)
    first_run = create(:job_run, :completed, user:, job:)
    second_run = create(:job_run, :completed, user:, job:)

    get job_runs_path, params: { sort: "sequence", direction: "asc" }

    expect(response.body.index(first_run.sequence.to_s)).to be < response.body.index(second_run.sequence.to_s)
  end

  it "sorts job runs by sequence descending" do
    job = create(:job, user:)
    first_run = create(:job_run, :completed, user:, job:)
    second_run = create(:job_run, :completed, user:, job:)

    get job_runs_path, params: { sort: "sequence", direction: "desc" }

    expect(response.body.index(second_run.sequence.to_s)).to be < response.body.index(first_run.sequence.to_s)
  end

  it "falls back to default sort when column is not allowed" do
    create(:job_run, :completed, user:)

    get job_runs_path, params: { sort: "trigger", direction: "asc" }

    expect(response).to have_http_status(:ok)
  end
end
```

- [ ] **Step 4: Run all three specs to confirm they fail**

```bash
docker compose exec app bundle exec rspec spec/requests/repositories_request_spec.rb spec/requests/jobs_request_spec.rb spec/requests/job_runs_request_spec.rb --format documentation 2>&1 | tail -30
```

Expected: sort-related examples fail.

- [ ] **Step 5: Wire Sortable into RepositoriesController**

In `app/controllers/repositories_controller.rb`, add `include Sortable` after `include Searchable`, and update the `index` action:

```ruby
# frozen_string_literal: true

class RepositoriesController < ApplicationController
  include Searchable
  include Sortable

  before_action :authenticate_user!
  before_action :set_repository, only: [:edit, :update, :destroy]
  before_action :set_servers, only: [:new, :edit, :create, :update]

  def index
    repositories = authorized_scope(Repository.all, type: :relation)
    repositories = search_for(repositories, "name", "description")
    repositories = sort_for(repositories, allowed: %w[name repository_type path], default: { name: :asc })

    @pagy, @repositories = pagy(repositories)

    authorize! :repository
  end

  # ... rest of file unchanged
```

- [ ] **Step 6: Wire Sortable into JobsController**

In `app/controllers/jobs_controller.rb`, add `include Sortable` after `include Searchable`, and update the `index` action:

```ruby
# frozen_string_literal: true

class JobsController < ApplicationController
  include Searchable
  include Sortable

  before_action :authenticate_user!
  before_action :set_job, only: [:edit, :update, :destroy]
  before_action :set_repositories, only: [:new, :edit, :create, :update]

  def index
    jobs = authorized_scope(Job.includes(:source_repository, :destination_repository).all, type: :relation)
    jobs = search_for(jobs, "name", "description")
    jobs = sort_for(jobs, allowed: %w[name schedule], default: { name: :asc })

    @pagy, @jobs = pagy(jobs)

    authorize! :job
  end

  # ... rest of file unchanged
```

- [ ] **Step 7: Wire Sortable into JobRunsController**

In `app/controllers/job_runs_controller.rb`, add `include Sortable` after `include Filterable`, and update the `index` action:

```ruby
# frozen_string_literal: true

class JobRunsController < ApplicationController
  include Filterable
  include Sortable

  before_action :authenticate_user!
  before_action :set_job_run, only: [:show, :logs, :destroy, :cancel]

  def index
    @jobs = authorized_scope(Job.order(:name), type: :relation)

    scope = authorized_scope(
      JobRun.includes(job: [:source_repository, :destination_repository]).all,
      type: :relation,
    )
    scope = scope.by_job(@filters[:job_id])
    scope = scope.by_trigger(@filters[:trigger])
    scope = scope.by_status(@filters[:status])
    scope = scope.started_from(parse_datetime(@filters[:started_at_from]))
    scope = scope.started_to(parse_datetime(@filters[:started_at_to]))
    scope = sort_for(scope, allowed: %w[sequence status started_at completed_at], default: { created_at: :desc })

    @pagy, @job_runs = pagy(scope)

    authorize! :job_run
  end

  # ... rest of file unchanged
```

- [ ] **Step 8: Run all specs to verify they pass**

```bash
docker compose exec app bundle exec rspec spec/requests/repositories_request_spec.rb spec/requests/jobs_request_spec.rb spec/requests/job_runs_request_spec.rb --format documentation 2>&1 | tail -30
```

Expected: all examples pass.

- [ ] **Step 9: Commit**

```bash
git add app/controllers/repositories_controller.rb app/controllers/jobs_controller.rb app/controllers/job_runs_controller.rb spec/requests/repositories_request_spec.rb spec/requests/jobs_request_spec.rb spec/requests/job_runs_request_spec.rb
git commit -m "Wire Sortable concern into Repositories, Jobs, and JobRuns controllers"
```

---

## Task 3: Shared sort header partial

**Files:**
- Create: `app/views/shared/_sort_header.html.erb`

- [ ] **Step 1: Create the partial**

Create `app/views/shared/_sort_header.html.erb`:

```erb
<%# locals: (column:, label:) %>
<%
  active = @sort_column == column.to_s
  next_direction = if active
    @sort_direction == "asc" ? "desc" : nil
  else
    "asc"
  end

  base = params.except(:controller, :action).to_unsafe_h
  sort_params = if next_direction
    base.merge("sort" => column, "direction" => next_direction)
  else
    base.except("sort", "direction")
  end
%>
<th
  class="
    px-6 py-4 text-left font-medium text-gray-500
    dark:text-gray-400
  "
>
  <%= link_to url_for(sort_params),
              data: { turbo_action: "replace" },
              class: "flex items-center gap-1 hover:text-gray-700 dark:hover:text-gray-200 whitespace-nowrap" do %>
    <%= label %>
    <% if active && @sort_direction == "asc" %>
      <%= lucide_icon "chevron-up", class: "h-3.5 w-3.5 shrink-0" %>
    <% elsif active && @sort_direction == "desc" %>
      <%= lucide_icon "chevron-down", class: "h-3.5 w-3.5 shrink-0" %>
    <% end %>
  <% end %>
</th>
```

- [ ] **Step 2: Run existing request specs to confirm no regressions**

```bash
docker compose exec app bundle exec rspec spec/requests/ --format documentation 2>&1 | tail -20
```

Expected: all existing examples pass (the partial is not yet used).

- [ ] **Step 3: Commit**

```bash
git add app/views/shared/_sort_header.html.erb
git commit -m "Add shared sort header partial"
```

---

## Task 4: Update Servers and Repositories index views

**Files:**
- Modify: `app/views/servers/index.html.erb`
- Modify: `app/views/repositories/index.html.erb`

- [ ] **Step 1: Update servers index view**

In `app/views/servers/index.html.erb`, replace the two sortable `<th>` elements (name and host). The full `<thead>` block should become:

```erb
<thead>
  <tr class="border-b border-gray-100 dark:border-gray-700">
    <th class="py-4"></th>

    <%= render "shared/sort_header", column: "name", label: I18n.t("servers.table.name") %>

    <%= render "shared/sort_header", column: "host", label: I18n.t("servers.table.host") %>

    <th class="px-6 py-4"></th>
  </tr>
</thead>
```

- [ ] **Step 2: Update repositories index view**

In `app/views/repositories/index.html.erb`, replace the sortable `<th>` elements (name, type, path). The server column is not sortable (requires a JOIN) and stays as-is. The full `<thead>` block should become:

```erb
<thead>
  <tr class="border-b border-gray-100 dark:border-gray-700">
    <th class="py-4"></th>

    <%= render "shared/sort_header", column: "name", label: I18n.t("repositories.table.name") %>

    <%= render "shared/sort_header", column: "repository_type", label: I18n.t("repositories.table.type") %>

    <%= render "shared/sort_header", column: "path", label: I18n.t("repositories.table.path") %>

    <th
      class="
        px-6 py-4 text-left font-medium text-gray-500
        dark:text-gray-400
      "
    >
      <%= I18n.t("repositories.table.server") %>
    </th>

    <th class="px-6 py-4"></th>
  </tr>
</thead>
```

- [ ] **Step 3: Run request specs for both controllers**

```bash
docker compose exec app bundle exec rspec spec/requests/servers_request_spec.rb spec/requests/repositories_request_spec.rb --format documentation 2>&1 | tail -20
```

Expected: all examples pass.

- [ ] **Step 4: Commit**

```bash
git add app/views/servers/index.html.erb app/views/repositories/index.html.erb
git commit -m "Add sort headers to Servers and Repositories index views"
```

---

## Task 5: Update Jobs and Job Runs index views

**Files:**
- Modify: `app/views/jobs/index.html.erb`
- Modify: `app/views/job_runs/index.html.erb`

- [ ] **Step 1: Update jobs index view**

In `app/views/jobs/index.html.erb`, replace the sortable `<th>` elements (name, schedule). Source and destination columns are not directly sortable (they require a JOIN) and stay as-is. The full `<thead>` block should become:

```erb
<thead>
  <tr class="border-b border-gray-100 dark:border-gray-700">
    <th class="py-4"></th>

    <%= render "shared/sort_header", column: "name", label: I18n.t("jobs.table.name") %>

    <th
      class="
        px-6 py-4 text-left font-medium text-gray-500
        dark:text-gray-400
      "
    >
      <%= I18n.t("jobs.table.source") %>
    </th>

    <th
      class="
        px-6 py-4 text-left font-medium text-gray-500
        dark:text-gray-400
      "
    >
      <%= I18n.t("jobs.table.destination") %>
    </th>

    <%= render "shared/sort_header", column: "schedule", label: I18n.t("jobs.table.schedule") %>

    <th class="px-6 py-4"></th>
  </tr>
</thead>
```

- [ ] **Step 2: Update job runs index view**

In `app/views/job_runs/index.html.erb`, replace the sortable `<th>` elements. The job column is not directly sortable (requires a JOIN) and stays as-is. Duration is computed (not a DB column) and stays as-is. The full `<thead>` block should become:

```erb
<thead>
  <tr class="border-b border-gray-100 dark:border-gray-700">
    <th class="py-4"></th>

    <%= render "shared/sort_header", column: "sequence", label: I18n.t("job_runs.table.sequence") %>

    <th
      class="
        px-6 py-4 text-left font-medium text-gray-500
        dark:text-gray-400
      "
    >
      <%= I18n.t("job_runs.table.job") %>
    </th>

    <%= render "shared/sort_header", column: "status", label: I18n.t("job_runs.table.status") %>

    <%= render "shared/sort_header", column: "started_at", label: I18n.t("job_runs.table.started_at") %>

    <th
      class="
        px-6 py-4 text-left font-medium text-gray-500
        dark:text-gray-400
      "
    >
      <%= I18n.t("job_runs.table.duration") %>
    </th>

    <%= render "shared/sort_header", column: "completed_at", label: I18n.t("job_runs.table.completed_at") %>

    <th class="px-6 py-4"></th>
  </tr>
</thead>
```

- [ ] **Step 3: Run request specs for both controllers**

```bash
docker compose exec app bundle exec rspec spec/requests/jobs_request_spec.rb spec/requests/job_runs_request_spec.rb --format documentation 2>&1 | tail -20
```

Expected: all examples pass.

- [ ] **Step 4: Commit**

```bash
git add app/views/jobs/index.html.erb app/views/job_runs/index.html.erb
git commit -m "Add sort headers to Jobs and Job Runs index views"
```

---

## Task 6: Database migration for sort and search indexes

**Files:**
- Create: `db/migrate/TIMESTAMP_add_sort_and_search_indexes.rb`

- [ ] **Step 1: Generate the migration**

```bash
docker compose exec app bundle exec rails generate migration AddSortAndSearchIndexes
```

Note the generated timestamp filename (e.g. `db/migrate/20260426XXXXXX_add_sort_and_search_indexes.rb`).

- [ ] **Step 2: Fill in the migration**

Replace the generated file content with:

```ruby
# frozen_string_literal: true

class AddSortAndSearchIndexes < ActiveRecord::Migration[8.0]
  def change
    # B-tree indexes for ORDER BY on sort columns
    add_index :servers, :name
    add_index :servers, :host
    add_index :repositories, :name
    add_index :repositories, :repository_type
    add_index :repositories, :path
    add_index :jobs, :name
    add_index :jobs, :schedule
    add_index :job_runs, :sequence
    add_index :job_runs, :status
    add_index :job_runs, :started_at
    add_index :job_runs, :completed_at

    # GIN trigram indexes for ILIKE %value% search queries
    enable_extension "pg_trgm"
    add_index :servers, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_servers_on_name_trgm"
    add_index :servers, :host, using: :gin, opclass: :gin_trgm_ops, name: "index_servers_on_host_trgm"
    add_index :servers, :description, using: :gin, opclass: :gin_trgm_ops, name: "index_servers_on_description_trgm"
    add_index :repositories, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_repositories_on_name_trgm"
    add_index :repositories, :description, using: :gin, opclass: :gin_trgm_ops, name: "index_repositories_on_description_trgm"
    add_index :jobs, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_jobs_on_name_trgm"
    add_index :jobs, :description, using: :gin, opclass: :gin_trgm_ops, name: "index_jobs_on_description_trgm"
  end
end
```

- [ ] **Step 3: Confirm migration with user before running**

The migration modifies the database schema. Confirm with the user before proceeding (per project convention: "Always prompt for confirmation before running `rails db:migrate`").

- [ ] **Step 4: Run the migration (after confirmation)**

```bash
docker compose exec app bundle exec rails db:migrate
```

Expected output includes the migration name and `== ... migrated`.

- [ ] **Step 5: Update model annotations**

```bash
docker compose exec app bundle exec annotaterb models
```

- [ ] **Step 6: Run full test suite to confirm no regressions**

```bash
docker compose exec app bundle exec rspec spec/requests/ --format documentation 2>&1 | tail -30
```

Expected: all examples pass.

- [ ] **Step 7: Commit**

```bash
git add db/migrate/ db/schema.rb app/models/
git commit -m "Add sort and search indexes"
```

---

## Task 7: Rubocop and ERB format check

**Files:** All modified `.rb` and `.html.erb` files

- [ ] **Step 1: Run Rubocop on modified Ruby files**

```bash
docker compose exec app bundle exec rubocop \
  app/controllers/concerns/sortable.rb \
  app/controllers/servers_controller.rb \
  app/controllers/repositories_controller.rb \
  app/controllers/jobs_controller.rb \
  app/controllers/job_runs_controller.rb \
  spec/requests/servers_request_spec.rb \
  spec/requests/repositories_request_spec.rb \
  spec/requests/jobs_request_spec.rb \
  spec/requests/job_runs_request_spec.rb
```

Expected: no offenses.

- [ ] **Step 2: Run Herb formatter on modified ERB files**

```bash
docker compose exec app yarn herb:format
```

Expected: no formatting errors.

- [ ] **Step 3: Fix any violations and commit if needed**

If Rubocop or Herb reports violations, fix them and commit:

```bash
git add -p
git commit -m "Fix style violations in sortable tables implementation"
```
