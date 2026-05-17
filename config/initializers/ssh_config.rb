# frozen_string_literal: true

Rails.application.config.after_initialize do
  next if Rails.env.test?
  next unless ActiveRecord::Base.connection.table_exists?(:servers)

  Servers::SyncSSHConfigJob.perform_later
rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
  nil
end
