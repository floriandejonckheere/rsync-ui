# Repositories Feature Design

**Date:** 2026-04-18
**Status:** Approved

## Objective

Implement full CRUD management for Repositories — the local or remote directories that rsync synchronization jobs read from and write to.

## Assumptions & Non-Goals

- No show action (detail page); index + edit is sufficient, mirroring the Servers feature.
- No soft-delete; hard destroy is used.
- Server association is scoped to the current user's servers only (policy-enforced).
- No file-system path validation at this stage (path is a free-text string).

---

## Data Model

**Table:** `repositories`

| Column | Type | Constraints |
|---|---|---|
| `id` | uuid | PK |
| `name` | string | not null |
| `description` | text | nullable |
| `repository_type` | string | not null, enum: `local` / `remote` |
| `server_id` | uuid | nullable FK → servers |
| `path` | string | not null |
| `read_only` | boolean | default false, not null |
| `user_id` | uuid | not null FK → users |
| `created_at` / `updated_at` | datetime | |

**Column naming:** `repository_type` (not `type`) to avoid Rails STI collision.

**Model validations:**
- `name`: presence
- `repository_type`: presence, inclusion in `%w[local remote]`
- `path`: presence
- `server_id`: presence when `repository_type == "remote"`; must be absent (or nil) when `repository_type == "local"`
- `belongs_to :user`
- `belongs_to :server, optional: true`

**Enum declaration:**
```ruby
enum :repository_type, { local: "local", remote: "remote" }
```

---

## Authorization (Policy)

**`RepositoryPolicy`** mirrors `ServerPolicy`:

| Action | Allowed |
|---|---|
| `index?` | any authenticated user |
| `create?` | any authenticated user |
| `edit?` | admin or record owner |
| `update?` | admin or record owner |
| `destroy?` | admin or record owner |
| `relation_scope` | admin sees all; user sees own |

---

## Controller

**`RepositoriesController`:**
- `before_action :authenticate_user!`
- `before_action :set_repository, only: [:edit, :update, :destroy]`
- `index`: `authorized_scope(Repository.order(:name), type: :relation)`
- `new`: `Repository.new(repository_type: "local")` — sets default so form loads with Local tab active
- `create`: `current_user.repositories.build(repository_params)`, redirect to `repositories_path`
- `update`: update + redirect to `repositories_path`
- `destroy`: hard destroy + redirect to `repositories_path`
- Strong params: `name`, `description`, `repository_type`, `server_id`, `path`, `read_only`
- **`server_id` scrubbing:** when `repository_type == "local"`, force `server_id` to `nil` in the permitted params (HTML hidden panels still submit their fields)

**Routes:** `resources :repositories` added to `config/routes.rb`.

---

## Views

### Index (`app/views/repositories/index.html.erb`)

Table with columns: Name, Type (badge: local/remote), Path, Server (name or "—"), Read-only, Actions (edit, delete).
Empty state card with folder icon when no repositories exist.

### Form (`app/views/repositories/_form.html.erb`)

Two-column layout:

- **Left column:**
  - Details card: name, description
  - Location card: path (text field), read-only (checkbox)

- **Right column:**
  - Type card with Basecoat tabs ("Local" tab | "Remote" tab)
    - Hidden `<input type="hidden" name="repository[repository_type]">` synced by Stimulus
    - **Local panel:** informational hint only (no extra fields)
    - **Remote panel:** server `<select>` populated from `current_user`'s servers (scoped via policy)

### New / Edit

Minimal wrappers that render `_form`. Same pattern as servers.

---

## Stimulus Controller

**File:** `app/javascript/controllers/repository_type_controller.js`

**Targets:** `tab` (buttons), `panel` (divs), `input` (hidden field)

**Behavior:**
- `connect()`: reads the current hidden input value and activates the matching tab + panel (critical for the edit form pre-population).
- `select(event)`: on tab button click — sets `aria-selected="true"` on clicked tab / `"false"` on others, removes `hidden` from matching panel / adds `hidden` to others, writes the tab's `data-value` to the hidden input.

---

## Sidebar Navigation

Add a Repositories menu item between Servers and the admin/configuration section in `app/views/layouts/application.html.erb`:

```erb
<%= render "shared/menu_item", path: repositories_path, controllers: "repositories", icon: "folders", title: I18n.t("repositories.title") %>
```

---

## Testing

### Factory (`spec/factories/repositories.rb`)

- Default / `:local` trait: `repository_type: "local"`, no server, user association
- `:remote` trait: `repository_type: "remote"`, associated server (via `server` factory)

### Model Spec (`spec/models/repository_spec.rb`)

- `belongs_to :user`
- `belongs_to :server` (optional)
- `validates_presence_of :name, :repository_type, :path`
- Server required when remote (cross-field validation)
- Server must be nil when local (cross-field validation)

### Policy Spec (`spec/policies/repository_policy_spec.rb`)

- `index?` / `create?` — true for any user
- `edit?` / `update?` / `destroy?` — true for owner, false for other user, true for admin
- `relation_scope` — filters to own records; admin gets all

### Request Spec (`spec/requests/repositories_request_spec.rb`)

| Endpoint | Scenario | Expected |
|---|---|---|
| GET /repositories | authenticated | 200 |
| GET /repositories | unauthenticated | redirect to sign in |
| GET /repositories/new | authenticated | 200 |
| GET /repositories/new | unauthenticated | redirect to sign in |
| POST /repositories | valid params | creates record, redirect to index |
| POST /repositories | invalid params | 422, no record created |
| POST /repositories | unauthenticated | redirect to sign in |
| GET /repositories/:id/edit | own record | 200 |
| GET /repositories/:id/edit | other user's record | 403 |
| GET /repositories/:id/edit | unauthenticated | redirect to sign in |
| PATCH /repositories/:id | own record, valid | updates record, redirect to index |
| PATCH /repositories/:id | invalid params | 422 |
| PATCH /repositories/:id | other user's record | 403 |
| PATCH /repositories/:id | unauthenticated | redirect to sign in |
| DELETE /repositories/:id | own record | destroys record, redirect to index |
| DELETE /repositories/:id | other user's record | 403 |
| DELETE /repositories/:id | unauthenticated | redirect to sign in |
