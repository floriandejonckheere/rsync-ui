# frozen_string_literal: true

module Configurations
  class VerifyHostKeyService < ApplicationService
    def call
      Servers::SyncSSHConfigJob.perform_later
    end
  end
end
