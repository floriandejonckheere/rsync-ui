# frozen_string_literal: true

module Servers
  class SyncSSHConfigJob < ApplicationJob
    def perform
      SSHConfigService.call
    end
  end
end
