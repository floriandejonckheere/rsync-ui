# frozen_string_literal: true

module Tasks
  class SyncSSHConfigService < ApplicationService
    def call
      Servers::SSHConfigService.call
    end
  end
end
