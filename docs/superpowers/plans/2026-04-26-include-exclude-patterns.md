# Include/Exclude Patterns Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `opt_include` and `opt_exclude` text-array columns to jobs, wire them into the rsync command builder, and expose a collapsible "Include/exclude patterns" card in the job form with add/remove UI.

**Architecture:** Two PostgreSQL `text[]` columns store ordered lists of include/exclude patterns. The rsync command service appends `--include=PATTERN` flags (all includes) followed by `--exclude=PATTERN` flags (all excludes). A new Stimulus controller (`pattern-list`) handles DOM add/remove of pattern input rows without server round-trips; a hidden sentinel input ensures empty lists are persisted on submit.

**Tech Stack:** Rails 8 migrations, RSpec request + service specs, Stimulus (Hotwire), ERB + Tailwind/Basecoat, I18n

---

## File Map

| Action | Path |
|--------|------|
| Create | `db/migrate/20260426200000_add_include_exclude_to_jobs.rb` |
| Auto-update | `db/schema.rb` (by migration) |
| Auto-update | `app/models/job.rb` (by annotaterb) |
| Modify | `app/services/rsync/command_service.rb` |
| Modify | `spec/services/rsync/command_service_spec.rb` |
| Modify | `app/controllers/jobs_controller.rb` |
| Modify | `spec/requests/jobs_request_spec.rb` |
| Create | `app/javascript/controllers/pattern_list_controller.js` |
| Auto-update | `app/javascript/controllers/index.js` (by stimulus:manifest:update) |
| Modify | `app/views/jobs/_form.html.erb` |
| Modify | `config/locales/en.yml` |

---

## Task 1: Migration — add opt_include and opt_exclude columns

**Files:**
- Create: `db/migrate/20260426200000_add_include_exclude_to_jobs.rb`

- [ ] **Step 1: Create the migration file**

```ruby
# db/migrate/20260426200000_add_include_exclude_to_jobs.rb
# frozen_string_literal: true

class AddIncludeExcludeToJobs < ActiveRecord::Migration[8.1]
  def change
    change_table :jobs, bulk: true do |t|
      t.text :opt_include, array: true, null: false, default: []
      t.text :opt_exclude, array: true, null: false, default: []
    end
  end
end
```

- [ ] **Step 2: Prompt for confirmation, then run the migration**

```bash
docker compose exec app bundle exec rails db:migrate
```

Expected: migration runs without error and prints `AddIncludeExcludeToJobs: migrated`.

- [ ] **Step 3: Annotate the model**

```bash
docker compose exec app bundle exec annotaterb models
```

Expected: `app/models/job.rb` annotation block updated to show `opt_include` and `opt_exclude` columns.

- [ ] **Step 4: Commit**

```bash
git add db/migrate/20260426200000_add_include_exclude_to_jobs.rb db/schema.rb app/models/job.rb
git commit -m "Add opt_include and opt_exclude columns to jobs"
```

---

## Task 2: Command service — include/exclude flags (TDD)

**Files:**
- Modify: `spec/services/rsync/command_service_spec.rb`
- Modify: `app/services/rsync/command_service.rb`

- [ ] **Step 1: Write the failing tests**

Add these three `describe` blocks to `spec/services/rsync/command_service_spec.rb`, after the existing `"opt_arguments"` block (before `"missing repositories"`):

```ruby
describe "opt_include" do
  context "when patterns are present" do
    before { job.opt_include = ["*.log", "docs/"] }

    it "adds a --include flag for each pattern" do
      expect(command).to include("--include=*.log")
      expect(command).to include("--include=docs/")
    end

    it "places include flags before the source path" do
      expect(command.index("--include=*.log")).to be < command.index("/data/source")
    end
  end

  context "when empty" do
    before { job.opt_include = [] }

    it "adds no --include flags" do
      expect(command).not_to include("--include=")
    end
  end
end

describe "opt_exclude" do
  context "when patterns are present" do
    before { job.opt_exclude = ["*.tmp", ".cache/"] }

    it "adds a --exclude flag for each pattern" do
      expect(command).to include("--exclude=*.tmp")
      expect(command).to include("--exclude=.cache/")
    end
  end

  context "when empty" do
    before { job.opt_exclude = [] }

    it "adds no --exclude flags" do
      expect(command).not_to include("--exclude=")
    end
  end
end

describe "include/exclude ordering" do
  before do
    job.opt_include = ["*.log"]
    job.opt_exclude = ["*.tmp"]
  end

  it "places all --include flags before all --exclude flags" do
    expect(command.index("--include=*.log")).to be < command.index("--exclude=*.tmp")
  end
end
```

- [ ] **Step 2: Run to verify they fail**

```bash
docker compose exec app bundle exec rspec spec/services/rsync/command_service_spec.rb --format documentation
```

Expected: the new examples fail with `NoMethodError` or similar (columns don't exist on the unsaved `build(:job)` object yet — if the migration ran in Task 1 they'll fail with the flag not found in command output).

- [ ] **Step 3: Implement include/exclude flags in the command service**

In `app/services/rsync/command_service.rb`, update the `call` method and add two private helpers:

```ruby
def call
  [
    # Command
    "rsync",

    # Flags
    *ssh_flags,
    *boolean_flags(BASIC_FLAGS),
    *boolean_flags(ADVANCED_FLAGS),
    *rsync_path_flag,
    *custom_argument_flags,
    *include_flags,
    *exclude_flags,

    # Mandatory flags
    "--info=progress2", # Show total progress
    "--no-inc-recursive", # Compute total files to transfer upfront

    # Source and destination paths
    source_path,
    destination_path,
  ].compact.uniq.join(" ")
end
```

Add these two private methods after `custom_argument_flags`:

```ruby
def include_flags
  job.opt_include.map { |pattern| "--include=#{pattern}" }
end

def exclude_flags
  job.opt_exclude.map { |pattern| "--exclude=#{pattern}" }
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
docker compose exec app bundle exec rspec spec/services/rsync/command_service_spec.rb --format documentation
```

Expected: all examples pass.

- [ ] **Step 5: Run rubocop**

```bash
docker compose exec app bundle exec rubocop app/services/rsync/command_service.rb spec/services/rsync/command_service_spec.rb
```

Expected: no offenses.

- [ ] **Step 6: Commit**

```bash
git add app/services/rsync/command_service.rb spec/services/rsync/command_service_spec.rb
git commit -m "Add include/exclude pattern flags to rsync command builder"
```

---

## Task 3: Controller — permit opt_include and opt_exclude (TDD)

**Files:**
- Modify: `spec/requests/jobs_request_spec.rb`
- Modify: `app/controllers/jobs_controller.rb`

- [ ] **Step 1: Write the failing tests**

Inside `describe "POST /jobs"`, inside `context "when authenticated"`, add these two examples after the existing "creates the job" example:

```ruby
it "saves opt_include patterns" do
  post jobs_path, params: {
    job: valid_params[:job].merge(opt_include: ["*.log", "docs/"], opt_exclude: []),
  }

  expect(user.jobs.last.opt_include).to eq(["*.log", "docs/"])
end

it "saves opt_exclude patterns" do
  post jobs_path, params: {
    job: valid_params[:job].merge(opt_include: [], opt_exclude: ["*.tmp"]),
  }

  expect(user.jobs.last.opt_exclude).to eq(["*.tmp"])
end

it "saves empty arrays when blank pattern values are submitted" do
  post jobs_path, params: {
    job: valid_params[:job].merge(opt_include: ["", ""], opt_exclude: [""]),
  }

  job = user.jobs.last
  expect(job.opt_include).to eq([])
  expect(job.opt_exclude).to eq([])
end
```

- [ ] **Step 2: Run to verify they fail**

```bash
docker compose exec app bundle exec rspec spec/requests/jobs_request_spec.rb --format documentation
```

Expected: the three new examples fail (unpermitted parameters, or empty arrays not coerced).

- [ ] **Step 3: Update job_params in the controller**

In `app/controllers/jobs_controller.rb`, add `opt_include: []` and `opt_exclude: []` to the `permit` call (after `:opt_rsync_path`):

```ruby
def job_params
  permitted = params
    .require(:job)
    .permit(
      :name,
      :description,
      :source_repository_id,
      :destination_repository_id,
      :schedule,
      :enabled,
      :opt_archive,
      :opt_recursive,
      :opt_relative,
      :opt_links,
      :opt_times,
      :opt_perms,
      :opt_owner,
      :opt_group,
      :opt_one_file_system,
      :opt_delete,
      :opt_delete_excluded,
      :opt_existing,
      :opt_ignore_existing,
      :opt_update,
      :opt_dry_run,
      :opt_inplace,
      :opt_size_only,
      :opt_progress,
      :opt_acls,
      :opt_xattrs,
      :opt_hard_links,
      :opt_devices,
      :opt_specials,
      :opt_checksum,
      :opt_compress,
      :opt_partial,
      :opt_backup,
      :opt_append,
      :opt_numeric_ids,
      :opt_itemize_changes,
      :opt_secluded_args,
      :opt_verbose,
      :opt_superuser,
      :opt_arguments,
      :opt_rsync_path,
      opt_include: [],
      opt_exclude: [],
    )

  permitted[:source_repository_id] = permitted_repository_id(permitted[:source_repository_id]) if permitted.key?(:source_repository_id)
  permitted[:destination_repository_id] = permitted_repository_id(permitted[:destination_repository_id]) if permitted.key?(:destination_repository_id)
  permitted[:opt_include] = permitted.fetch(:opt_include, []).compact_blank
  permitted[:opt_exclude] = permitted.fetch(:opt_exclude, []).compact_blank

  permitted
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
docker compose exec app bundle exec rspec spec/requests/jobs_request_spec.rb --format documentation
```

Expected: all examples pass.

- [ ] **Step 5: Run rubocop**

```bash
docker compose exec app bundle exec rubocop app/controllers/jobs_controller.rb spec/requests/jobs_request_spec.rb
```

Expected: no offenses.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/jobs_controller.rb spec/requests/jobs_request_spec.rb
git commit -m "Permit opt_include and opt_exclude in job params"
```

---

## Task 4: Stimulus controller — pattern-list

**Files:**
- Create: `app/javascript/controllers/pattern_list_controller.js`
- Auto-update: `app/javascript/controllers/index.js`

- [ ] **Step 1: Create the Stimulus controller**

```javascript
// app/javascript/controllers/pattern_list_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "template"]
  static values = { fieldName: String, placeholder: String }

  add() {
    const clone = this.templateTarget.content.cloneNode(true)
    const input = clone.querySelector("input[type=text]")
    input.name = this.fieldNameValue
    input.placeholder = this.placeholderValue
    this.listTarget.appendChild(clone)
  }

  remove(event) {
    event.currentTarget.closest("[data-pattern-row]").remove()
  }
}
```

- [ ] **Step 2: Update the Stimulus manifest**

```bash
docker compose exec app bin/rails stimulus:manifest:update
```

Expected: `app/javascript/controllers/index.js` gains an import and `application.register("pattern-list", PatternListController)` line.

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/pattern_list_controller.js app/javascript/controllers/index.js
git commit -m "Add pattern-list Stimulus controller"
```

---

## Task 5: View and i18n — patterns card

**Files:**
- Modify: `config/locales/en.yml`
- Modify: `app/views/jobs/_form.html.erb`

- [ ] **Step 1: Add i18n keys**

In `config/locales/en.yml`, inside `en.jobs.form`, add these keys (in alphabetical order alongside existing keys):

```yaml
      add_pattern: Add pattern
      exclude_patterns: Exclude patterns
      include_exclude_patterns: Include/exclude patterns
      include_patterns: Include patterns
      pattern_placeholder: "e.g. *.log"
```

- [ ] **Step 2: Add the collapsible patterns card to the form**

In `app/views/jobs/_form.html.erb`, insert the following block after the preview card (after the closing `</div>` of the preview card at line ~112) and before the existing basic options `<details>` block:

```erb
      <details class="card group py-0">
        <summary
          class="
            flex items-center justify-between w-full px-8 py-8
            cursor-pointer list-none
          "
        >
          <h2 class="text-lg font-semibold">
            <%= I18n.t("jobs.form.include_exclude_patterns") %>
          </h2>

          <%= lucide_icon "chevron-down", class: "h-5 w-5 transition-transform duration-200 group-open:rotate-180" %>
        </summary>

        <div class="px-8 pb-8">
          <div class="grid grid-cols-2 gap-8">
            <div>
              <p class="font-medium mb-4"><%= I18n.t("jobs.form.include_patterns") %></p>

              <div
                data-controller="pattern-list"
                data-pattern-list-field-name-value="job[opt_include][]"
                data-pattern-list-placeholder-value="<%= I18n.t("jobs.form.pattern_placeholder") %>"
              >
                <template data-pattern-list-target="template">
                  <div data-pattern-row class="flex gap-2 items-center mb-2">
                    <input type="text" class="flex-1" autocomplete="off">
                    <button type="button" class="btn-icon-outline" data-action="pattern-list#remove">
                      <%= lucide_icon "trash-2", class: "h-4 w-4" %>
                    </button>
                  </div>
                </template>

                <input type="hidden" name="job[opt_include][]" value="">

                <div data-pattern-list-target="list">
                  <% job.opt_include.each do |pattern| %>
                    <div data-pattern-row class="flex gap-2 items-center mb-2">
                      <input
                        type="text"
                        name="job[opt_include][]"
                        value="<%= pattern %>"
                        placeholder="<%= I18n.t("jobs.form.pattern_placeholder") %>"
                        class="flex-1"
                        autocomplete="off"
                      >
                      <button type="button" class="btn-icon-outline" data-action="pattern-list#remove">
                        <%= lucide_icon "trash-2", class: "h-4 w-4" %>
                      </button>
                    </div>
                  <% end %>
                </div>

                <button type="button" class="btn-outline mt-2" data-action="pattern-list#add">
                  <%= lucide_icon "plus", class: "h-4 w-4 mr-1 inline" %>
                  <%= I18n.t("jobs.form.add_pattern") %>
                </button>
              </div>
            </div>

            <div>
              <p class="font-medium mb-4"><%= I18n.t("jobs.form.exclude_patterns") %></p>

              <div
                data-controller="pattern-list"
                data-pattern-list-field-name-value="job[opt_exclude][]"
                data-pattern-list-placeholder-value="<%= I18n.t("jobs.form.pattern_placeholder") %>"
              >
                <template data-pattern-list-target="template">
                  <div data-pattern-row class="flex gap-2 items-center mb-2">
                    <input type="text" class="flex-1" autocomplete="off">
                    <button type="button" class="btn-icon-outline" data-action="pattern-list#remove">
                      <%= lucide_icon "trash-2", class: "h-4 w-4" %>
                    </button>
                  </div>
                </template>

                <input type="hidden" name="job[opt_exclude][]" value="">

                <div data-pattern-list-target="list">
                  <% job.opt_exclude.each do |pattern| %>
                    <div data-pattern-row class="flex gap-2 items-center mb-2">
                      <input
                        type="text"
                        name="job[opt_exclude][]"
                        value="<%= pattern %>"
                        placeholder="<%= I18n.t("jobs.form.pattern_placeholder") %>"
                        class="flex-1"
                        autocomplete="off"
                      >
                      <button type="button" class="btn-icon-outline" data-action="pattern-list#remove">
                        <%= lucide_icon "trash-2", class: "h-4 w-4" %>
                      </button>
                    </div>
                  <% end %>
                </div>

                <button type="button" class="btn-outline mt-2" data-action="pattern-list#add">
                  <%= lucide_icon "plus", class: "h-4 w-4 mr-1 inline" %>
                  <%= I18n.t("jobs.form.add_pattern") %>
                </button>
              </div>
            </div>
          </div>
        </div>
      </details>
```

- [ ] **Step 3: Normalize i18n**

```bash
docker compose exec app i18n-tasks normalize
```

Expected: `config/locales/en.yml` is reformatted with keys in alphabetical order.

- [ ] **Step 4: Format ERB**

```bash
docker compose exec app yarn herb:format
```

Expected: `app/views/jobs/_form.html.erb` is reformatted cleanly.

- [ ] **Step 5: Run the full test suite to verify no regressions**

```bash
docker compose exec app bundle exec rspec spec/services/rsync/command_service_spec.rb spec/requests/jobs_request_spec.rb --format documentation
```

Expected: all examples pass.

- [ ] **Step 6: Commit**

```bash
git add app/views/jobs/_form.html.erb config/locales/en.yml
git commit -m "Add include/exclude patterns card to job form"
```
