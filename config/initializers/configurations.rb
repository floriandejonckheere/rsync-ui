# frozen_string_literal: true

return if ENV.fetch("SKIP_CONFIGURATION_CHECK", "0") == "1"

Rails.application.config.after_initialize do
  next unless Configuration.table_exists?

  saved_logger = ActiveRecord::Base.logger
  ActiveRecord::Base.logger = nil

  # Create missing configurations
  Configuration.configurations.each do |key, configuration|
    "Configuration::#{configuration[:type].camelize}"
      .constantize
      .create_with(value: configuration[:default])
      .find_or_create_by!(key:)
      .value
  end

  # Delete unused configurations
  Configuration
    .where
    .not(key: Configuration.configurations.keys)
    .delete_all
rescue ActiveRecord::NoDatabaseError
  # nil
ensure
  ActiveRecord::Base.logger = saved_logger
end
