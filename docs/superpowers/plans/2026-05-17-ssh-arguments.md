# SSH Arguments Field Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an `opt_ssh_arguments` text field to jobs so users can pass custom SSH options (e.g. `-vvv`) that are injected into the rsync `-e "ssh ..."` string.

**Architecture:** Add a nullable text column to the `jobs` table, inject it into `Rsync::CommandService#ssh_flags`, permit it in the controller, render it in the form view, and add I18n strings — all following the existing `opt_arguments`/`opt_rsync_path` patterns.

**Tech Stack:** Rails 8, PostgreSQL, RSpec, Hotwire/ERB, I18n

---

### Task 1: Database migration

**Files:**
- Create: `db/migrate/TIMESTAMP_add_ssh_arguments_to_jobs.rb`
- Modify: `app/models/job.rb` (annotation update after migration)

- [ ] **Step 1: Generate migration**

```bash
docker compose exec app rails generate migration AddSSHArgumentsToJobs opt_ssh_arguments:text
```

Verify the generated file in `db/migrate/` looks like:

```ruby
# frozen_string_literal: true

class AddSSHArgumentsToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :opt_ssh_arguments, :text
  end
end
```

- [ ] **Step 2: Run migration**

Confirm with the user before running, then:

```bash
docker compose exec app rails db:migrate
```

- [ ] **Step 3: Update model annotations**

```bash
docker compose exec app bundle exec annotaterb models
```

Verify `opt_ssh_arguments :text` appears in the `# == Schema Information` block at the bottom of `app/models/job.rb`.

- [ ] **Step 4: Commit**

```bash
git add db/migrate/ db/schema.rb app/models/job.rb
git commit -m "Add opt_ssh_arguments column to jobs"
```

---

### Task 2: Update Rsync::CommandService

**Files:**
- Modify: `app/services/rsync/command_service.rb`
- Test: `spec/services/rsync/command_service_spec.rb`

- [ ] **Step 1: Write failing tests**

Open `spec/services/rsync/command_service_spec.rb` and add tests for `opt_ssh_arguments`. Find the existing SSH flags examples and add:

```ruby
context "when opt_ssh_arguments is set" do
  let(:job) { build(:job, opt_ssh_arguments: "-vvv", source_repository: remote_repo, destination_repository: local_repo) }

  it "injects ssh arguments into the -e flag" do
    expect(service.call).to include("-vvv")
  end

  context "with ssh key" do
    before { allow(remote_repo.server).to receive(:ssh_key).and_return("key") }

    it "appends ssh arguments after the config flag" do
      expect(service.call).to include("ssh -F #{Dir.home}/.ssh/config -vvv")
    end
  end

  context "without ssh key" do
    before { allow(remote_repo.server).to receive(:ssh_key).and_return(nil) }

    it "appends ssh arguments after the config flag" do
      expect(service.call).to include("ssh -F #{Dir.home}/.ssh/config -vvv")
    end
  end
end

context "when opt_ssh_arguments is blank" do
  let(:job) { build(:job, opt_ssh_arguments: nil, source_repository: remote_repo, destination_repository: local_repo) }

  it "does not add extra content to the -e flag" do
    expect(service.call).not_to include("nil")
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
docker compose exec app bundle exec rspec spec/services/rsync/command_service_spec.rb
```

Expected: failures related to `opt_ssh_arguments` not yet being injected.

- [ ] **Step 3: Implement in CommandService**

In `app/services/rsync/command_service.rb`, update `ssh_flags` (lines 89–102):

```ruby
def ssh_flags
  # Only one server (source/destination) can be remote
  server = remote_server

  return [] unless server

  ssh_args = job.opt_ssh_arguments.present? ? " #{job.opt_ssh_arguments.strip}" : ""

  if server.ssh_key.present?
    # Authenticate using private key (via the SSH config file)
    ["-e \"ssh -F #{ssh_home}/config#{ssh_args}\""]
  else
    # Authenticate using password (via the non-interactive sshpass command)
    ["-e \"sshpass -f #{ssh_home}/#{server.slug}_password ssh -F #{ssh_home}/config#{ssh_args}\""]
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
docker compose exec app bundle exec rspec spec/services/rsync/command_service_spec.rb
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/rsync/command_service.rb spec/services/rsync/command_service_spec.rb
git commit -m "Inject opt_ssh_arguments into SSH command in Rsync::CommandService"
```

---

### Task 3: Permit in controller and add I18n strings

**Files:**
- Modify: `app/controllers/jobs_controller.rb`
- Modify: `config/locales/jobs/en.yml`

- [ ] **Step 1: Add to permitted params**

In `app/controllers/jobs_controller.rb`, add `:opt_ssh_arguments` to the permit list after `:opt_rsync_path` (around line 150):

```ruby
:opt_superuser,
:opt_arguments,
:opt_rsync_path,
:opt_ssh_arguments,
```

- [ ] **Step 2: Add I18n strings**

In `config/locales/jobs/en.yml`, add after the `opt_rsync_path` block (around line 176):

```yaml
      opt_ssh_arguments:
        description: Custom SSH options
        placeholder: e.g. -vvv
```

- [ ] **Step 3: Normalize i18n files**

```bash
docker compose exec app bundle exec i18n-tasks normalize
```

- [ ] **Step 4: Commit**

```bash
git add app/controllers/jobs_controller.rb config/locales/jobs/en.yml
git commit -m "Permit opt_ssh_arguments in jobs controller and add I18n strings"
```

---

### Task 4: Add form field to view

**Files:**
- Modify: `app/views/jobs/_form.html.erb`

- [ ] **Step 1: Add the field**

In `app/views/jobs/_form.html.erb`, inside the "Custom options" `<details>` block, add after the `opt_rsync_path` field (after line 449):

```erb
            <div class="field">
              <%= f.label :opt_ssh_arguments, I18n.t("jobs.form.opt_ssh_arguments.description") %>

              <%= f.text_area :opt_ssh_arguments,
                              placeholder: I18n.t("jobs.form.opt_ssh_arguments.placeholder"),
                              rows: 3,
                              autocomplete: "off" %>
            </div>
```

- [ ] **Step 2: Format ERB**

```bash
docker compose exec app yarn herb:format
```

- [ ] **Step 3: Verify in browser**

Open the job new/edit page and confirm the "Custom SSH options" field appears below "Alternate rsync path" in the Custom options section. Verify the command preview updates when text is entered.

- [ ] **Step 4: Commit**

```bash
git add app/views/jobs/_form.html.erb
git commit -m "Add opt_ssh_arguments field to job form"
```
