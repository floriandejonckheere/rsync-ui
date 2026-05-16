# frozen_string_literal: true

Rails.application.config.after_initialize do
  next if Rails.env.test?

  Servers::SyncSSHConfigJob.perform_later
end
