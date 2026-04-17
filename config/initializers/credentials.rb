# frozen_string_literal: true

return unless Rails.env.production?
return if ENV.fetch("SKIP_CREDENTIALS_CHECK", "0") == "1"

[
  "SECRET_KEY_BASE",
  "PG_HOST",
  "PG_USER",
  "PG_PASSWORD",
  "APP_HOST",
  "APP_EMAIL",
  "ADMIN_EMAIL",
  "ADMIN_PASSWORD",
  "APPSIGNAL_API_KEY",
].each do |key|
  next if ENV.key?(key) && ENV[key].present?

  raise ArgumentError, "Environment variable empty or not found: #{key}"
end
