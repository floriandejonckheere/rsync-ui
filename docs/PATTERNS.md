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

**In Locale Files** (`config/locales/en.yml`):
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
  enum :state, { pending: "pending", processing: "processing", completed: "completed", failed: "failed" }

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

And then add a translation entry in the `config/locales/configurations.yml` file.

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
