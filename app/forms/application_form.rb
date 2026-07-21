# frozen_string_literal: true

class ApplicationForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Aliased (not named `save?`) because Wicked's `render_wizard` calls `save` directly.
  alias save valid?
end
