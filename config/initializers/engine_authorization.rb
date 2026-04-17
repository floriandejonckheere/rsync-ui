# frozen_string_literal: true

# Configure mounted engines to use ActionPolicy for authorization
Rails.application.config.to_prepare do
  # Authorization module to be prepended to engine controllers
  module EngineAuthorization # rubocop:disable Lint/ConstantDefinitionInBlock
    extend ActiveSupport::Concern

    included do
      include ActionPolicy::Controller if defined?(ActionPolicy::Controller)

      before_action :authenticate_user!
    end
  end
end
