# frozen_string_literal: true

Rails.application.config.after_initialize do
  next unless Configuration.table_exists?

  saved_logger = ActiveRecord::Base.logger
  ActiveRecord::Base.logger = nil

  Configuration.configurations.each do |key, configuration|
    "Configuration::#{configuration[:type].camelize}"
      .constantize
      .create_with(value: configuration[:default])
      .find_or_create_by!(key:)
      .value
  end
rescue ActiveRecord::NoDatabaseError
  # nil
ensure
  ActiveRecord::Base.logger = saved_logger
end
