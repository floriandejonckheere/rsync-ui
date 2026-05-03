# Common Patterns & Best Practices

## General

- Always use `Time.zone.now` instead of `Time.current`

## I18n Pattern

**In Controllers:**
```ruby
def create
  if @model.save
    redirect_to @model, notice: t(".success")
  else
    render :new, alert: t(".error")
  end
end
```

**In Locale Files** (`config/locales/{module}/en.yml`):
```yaml
en:
  models:
    create:
      success: "Model was successfully created."
      error: "There was an error creating the model."
```

## Flash Messages Pattern

**In Layout** (`app/core/views/layouts/application.html.erb`):
```erb
<% flash.each do |type, message| %>
  <%= render MessageComponent.new(type: type, message: message) %>
<% end %>
```

**In Controllers:**
```ruby
redirect_to models_path, notice: "Model was successfully created."
redirect_to models_path, alert: "You are not authorized to perform this action."
```

## Background Job Pattern

**Create Job:**
```ruby
# frozen_string_literal: true

class ModelJob < ApplicationJob
  queue_as :default

  def perform(model)
    model.update!(state: "completed")
  rescue StandardError => e
    model.update!(state: "failed")

    raise e
  end
end
```

**Enqueue Job:**
```ruby
ModelJob.perform_later(model: @model)
```

## Migration Pattern

**Creating a migration:**
```bash
docker compose exec app bundle exec rails generate migration CreateModels
```

**Migration example:**
```ruby
class CreateModels < ActiveRecord::Migration[8.0]
  def change
    create_table :models, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.integer :state, default: 0, null: false

      t.timestamps
    end

    add_index :models, :state
  end
end
```

## Enum Pattern

**In Model:**
```ruby
class Model < ApplicationRecord
  enum :status, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed",
  }, validate: true

  # Generated methods:
  # - model.pending? / model.processing? / model.completed? / model.failed?
  # - Model.pending / Model.processing / etc. (scopes)
end
```

**In Forms:**
```erb
<%= f.select :state, Model.states.keys.map { |s| [s.humanize, s] } %>
```

## ActiveStorage Pattern

**In Model:**
```ruby
class Model < ApplicationRecord
  has_one_attached :file

  validates :file,
    attached: true,
    content_type: ["application/epub+zip"],
    size: { less_than: 100.megabytes }
end
```

**In Controller:**
```ruby
def create
  @model = current_user.models.build(model_params)

  if @model.save
    redirect_to @model, notice: "Model uploaded successfully"
  else
    render :new, status: :unprocessable_entity
  end
end

private

def model_params
  params.require(:model).permit(:file)
end
```

**In Views:**
```erb
<%= form_with model: @model do |f| %>
  <%= f.file_field :file, accept: "application/epub+zip" %>
<% end %>

<!-- Display attached file -->
<% if @model.file.attached? %>
  <%= link_to "Download", rails_blob_path(@model.file, disposition: "attachment") %>
<% end %>
```

## Discardable Model Pattern (Soft Deletes)

Use the `Discard` concern to implement soft deletes via a timestamp column (default: `discarded_at`).

**Migration:**
```ruby
class AddDiscardedAtToModels < ActiveRecord::Migration[8.0]
  def change
    add_column :models, :discarded_at, :datetime
    add_index :models, [:user_id, :discarded_at]
  end
end
```

**Model:**
```ruby
class Model < ApplicationRecord
  include Discard
end
```

**Controller/Service:**
```ruby
def destroy
  authorize! @model
  @model.discard!
  redirect_to models_path, status: :see_other
end
```

**Policy scope (hide discarded by default):**
```ruby
relation_scope do |scope|
  scope = scope.kept
  next scope if user.admin?
  scope.where(user:)
end
```

**Background jobs:**
```ruby
return if model.discarded?
```

**Notes:**
- Prefer explicit `discard!` calls over overriding `destroy`.
- If you add unique indexes, consider making them "unique among kept records" (partial index excluding `discarded_at`).

## Testing Patterns

### Model Spec Example
```ruby
RSpec.describe Model do
  subject(:model) { build(:model) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:title) }
end
```

### Request Spec Example
```ruby
RSpec.describe "Models" do
  let(:user) { create(:user) }

  before { sign_in(user) }

  describe "GET /models" do
    it "returns successful response" do
      get models_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /models" do
    it "creates a new Model" do
      expect { post models_path, params: { name: } }
      .to change(Model, :count).by(1)
    end
  end
end
```

### Policy Spec Example
```ruby
RSpec.describe ModelPolicy do
  subject(:policy) { described_class.new(record, user:) }

  let(:record) { build(:model) }
  let(:user) { build(:user) }

  describe "#index?" do
    it { is_expected.to be_index }
  end
end
```

## Configuration Pattern

When adding new system/application configuration, create an entry in the `app/configurations/configurations.yml` file.

```yaml
- key: namespace.my_new_configuration
  type: boolean
  category: features
  default: "my_default_value"
  dependencies:
    - namespace.my_old_configuration
```

And then add a translation entry in the `config/locales/configurations/en.yml` file.

```yaml
en:
  configurations:
    keys:
      namespace:
        my_new_configuration:
          description: "My New Configuration"
```

Configuration keys should use snake_case and be namespaced appropriately.
Configurations can have the following categories: features, system, other 
Configuration values can be of the following types: string, integer, float, boolean.

## Search Pattern

Use the `Searchable` concern to add search to an index action. It sets `@query` from params and provides `search_for` to apply a case-insensitive ILIKE filter across any number of columns.

**Controller:**
```ruby
class ModelsController < ApplicationController
  include Searchable

  def index
    models = authorized_scope(Model.order(:name), type: :relation)
    models = search_for(models, "name", "description")

    @pagy, @models = pagy(models)

    authorize! :model
  end
end
```

**View (`app/views/models/index.html.erb`):**
```erb
<% content_for :actions do %>
  <%= render "shared/search",
             url: models_path,
             query: @query,
             frame: "models_list",
             placeholder: I18n.t("models.index.search.placeholder"),
             title: I18n.t("models.index.search.title") %>
<% end %>

<%= turbo_frame_tag "models_list" do %>
  <% if @models.empty? && @query.present? %>
    <%= render "shared/search_no_results", title: I18n.t("models.index.search.no_results.title") %>
  <% elsif @models.empty? %>
    <%# empty state %>
  <% else %>
    <%# table %>
  <% end %>
<% end %>
```

**Locale (`config/locales/{module}/en.yml`):**
```yaml
models:
  index:
    search:
      no_results:
        title: No models found
      placeholder: Search by name or description...
      title: Search models
```

**Notes:**
- The `shared/search` partial renders a toggle button in the actions bar; the form submits to the Turbo Frame so the list updates without a full page reload.
- The search input auto-expands when `@query` is present (e.g. on page load with a pre-filled query).
- Debouncing is built into `search_controller.js` (300 ms default).

## Collapsible Card Pattern

Use native `<details>` elements with Basecoat card styling for expandable/collapsible sections.

**Basic Structure:**
```erb
<details id="unique-section-id" class="card group py-0">
  <summary class="flex items-center justify-between w-full px-6 py-6 cursor-pointer list-none">
    <h2 class="text-lg font-semibold">
      Section Title
    </h2>

    <%= lucide_icon "chevron-down",
                    class: "h-5 w-5 transition-transform duration-200 group-open:rotate-180" %>
  </summary>

  <div class="px-6 pb-6">
    <!-- Collapsible content here -->
  </div>
</details>
```

**Key Elements:**
- `<details>` - Native HTML element for collapsible content
- `<summary>` - Clickable header that toggles the content
- `list-none` - Removes the default disclosure triangle
- `group` and `group-open:rotate-180` - Rotates the chevron icon when open

**Initially Open:**
To have the section open by default, add the `open` attribute to the `<details>` element:
```erb
<details id="unique-section-id" class="card group py-0" open>
  <summary class="flex items-center justify-between w-full px-6 py-6 cursor-pointer list-none">
    <h2 class="text-lg font-semibold">
      Section Title
    </h2>

    <%= lucide_icon "chevron-down",
                    class: "h-5 w-5 transition-transform duration-200 group-open:rotate-180" %>
  </summary>

  <div class="px-6 pb-6">
    <!-- Content visible by default -->
  </div>
</details>
```

**URL Hash Navigation:**
Native `<details>` elements support deep-linking via URL hash automatically when the browser navigates to an element inside the collapsed content.


## Turbo Frame escape for row links

Links rendered inside a turbo_frame_tag must include data: { turbo_frame: "_top" } to trigger
full-page navigation. Without it, Turbo looks for a matching frame on the destination page and
renders nothing if it isn't found.

```erb
<%= link_to edit_foo_path(foo), data: { turbo_frame: "_top", tooltip: "..." }, class: "..." do %>
```

## Disable/enable toggle button

Inline toggle using button_to with a PATCH and a negated enabled param. The controller's update
 action handles it without a dedicated route.

```erb
<%= button_to foo_path(foo),
              params: { foo: { enabled: !foo.enabled? } },
              method: :patch,
              class: "btn-icon-outline btn-icon-md",
              form_class: "contents",
              data: { tooltip: I18n.t(foo.enabled? ? "foos.actions.disable" : "foos.actions.enable") } do %>
  <%= lucide_icon(foo.enabled? ? "icon-off" : "icon", class: "h-4 w-4") %>
<% end %>
```

## Greying out disabled rows

Apply opacity-50 conditionally on the <tr> to visually indicate a disabled record:

```erb
<tr class="... <%= "opacity-50" unless foo.enabled? %>">
```

## Disabled indicator column

A leading empty column that shows a status icon when disabled, keeping the layout consistent. Set `w-10` on the `<th>` so the column stays fixed-width whether or not the icon is present.

```erb
<th class="py-4 w-10"></th>
```

```erb
<td class="pl-6 py-4">
  <% unless foo.enabled? %>
    <div data-tooltip="<%= I18n.t("foos.enabled.false") %>">
      <%= lucide_icon "icon-off", class: "h-4 w-4 text-gray-400" %>
    </div>
  <% end %>
</td>
```

## Inline action button with turbo stream result

For actions like "test connection" or "send test notification" that don't save the record, place an action button in the form's `content_for :actions` bar alongside the save button. A separate mini-form syncs values from the main form via a Stimulus controller, submits to a collection route, and renders the result as a turbo stream toast.

**Routes** — use a collection route so it works for both new and persisted records:
```ruby
resources :foos do
  collection do
    post :test
  end
end
```

**Controller** — find-or-build, override fields from params, render `shared/action_result`:
```ruby
def test
  @foo = params[:foo_id].present? ? Foo.find(params[:foo_id]) : Foo.new
  @foo.user ||= current_user

  authorize! @foo, to: :test?

  @foo.url = params[:url] if params[:url].present?

  if @foo.url.blank?
    return render turbo_stream: turbo_stream.prepend(
      "notifications",
      partial: "shared/action_result",
      locals: { result: { success: false, message: t(".missing_url") }, success_message: t(".success"), failure_message: t(".failure") },
    )
  end

  result = Foos::TestService.call(@foo)

  render turbo_stream: turbo_stream.prepend(
    "notifications",
    partial: "shared/action_result",
    locals: { result:, success_message: t(".success"), failure_message: t(".failure") },
  )
end
```

**Form** — a hidden mini-form inside `content_for :actions` that is wired to a Stimulus controller:
```erb
<%= form_with url: test_foos_path,
              method: :post,
              data: {
                turbo_stream: true,
                controller: "foo-test",
                "foo-test-source-form-value": "foo-form",
              } do |tf| %>
  <%= tf.hidden_field :foo_id, value: foo.persisted? ? foo.id : nil,
                      data: { "foo-test-target": "fooId" } %>
  <%= tf.hidden_field :url, data: { "foo-test-target": "url" } %>

  <button type="submit"
          class="btn-icon-outline btn-icon-lg"
          data-foo-test-target="button"
          data-action="click->foo-test#sync"
          data-tooltip="<%= I18n.t("foos.actions.test") %>"
          disabled>
    <%= lucide_icon "send", class: "h-6 w-6", data: { "foo-test-target": "icon" } %>
    <%= lucide_icon "loader-circle", class: "h-6 w-6 hidden animate-spin",
                    data: { "foo-test-target": "spinner" } %>
  </button>
<% end %>
```

**Stimulus controller** — watches the source form for input, enables the button when required fields are filled, syncs values on click:
```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "icon", "spinner", "url", "fooId"]
  static values = { sourceForm: String }

  connect() {
    this.element.addEventListener("turbo:submit-start", () => this.#setLoading(true))
    this.element.addEventListener("turbo:submit-end", () => this.#setLoading(false))

    const form = document.getElementById(this.sourceFormValue)
    if (form) {
      this.#sourceFormListener = () => this.#updateButton(form)
      form.addEventListener("input", this.#sourceFormListener)
      this.#updateButton(form)
    }
  }

  disconnect() {
    const form = document.getElementById(this.sourceFormValue)
    if (form && this.#sourceFormListener) {
      form.removeEventListener("input", this.#sourceFormListener)
    }
  }

  sync() {
    const form = document.getElementById(this.sourceFormValue)
    this.urlTarget.value = form.querySelector("[name='foo[url]']").value
  }

  #sourceFormListener = null

  #updateButton(form) {
    const url = form.querySelector("[name='foo[url]']")?.value.trim()
    this.buttonTarget.disabled = !url
  }

  #setLoading(loading) {
    this.buttonTarget.disabled = loading
    this.iconTarget.classList.toggle("hidden", loading)
    this.spinnerTarget.classList.toggle("hidden", !loading)
  }
}
```

**Shared result partial** (`app/views/shared/_action_result.html.erb`) — renders a dismissible toast prepended to the `notifications` turbo frame:
```erb
<div class="fixed top-4 left-1/2 -translate-x-1/2 z-50 w-full max-w-md px-4 sm:max-w-lg">
  <div role="alert"
       class="<%= alert_class_for(result[:success] ? :success : :alert) %> mb-4 shadow-lg relative"
       data-turbo-temporary
       data-controller="dismissible">
    <%= lucide_icon icon_name_for(result[:success] ? :success : :alert), class: "w-4 h-4" %>
    <h2><%= result[:success] ? success_message : failure_message %></h2>
    <% unless result[:success] %>
      <section>
        <pre class="text-xs whitespace-pre-wrap"><%= result[:message] %></pre>
      </section>
    <% end %>
    <button type="button" class="absolute top-2 right-2 btn-icon-ghost p-1"
            aria-label="<%= I18n.t("shared.dismiss") %>"
            data-action="dismissible#dismiss">
      <%= lucide_icon "x", class: "w-4 h-4" %>
    </button>
  </div>
</div>
```
