# frozen_string_literal: true

return if ENV.fetch("SKIP_SSH_CONFIG_SYNC", "0") == "1"

Rails.application.config.after_initialize do
  next if Rails.env.test?
  next unless ActiveRecord::Base.connection.table_exists?(:servers)

  Servers::SyncSSHConfigJob.perform_later
rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
  nil
end
