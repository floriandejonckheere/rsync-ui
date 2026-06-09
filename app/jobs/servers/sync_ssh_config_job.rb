# frozen_string_literal: true

module Servers
  class SyncSSHConfigJob < ApplicationJob
    limits_concurrency to: 1,
                       key: "sync_ssh_config_job",
                       duration: 15.seconds

    def perform
      SSHConfigService.call
    end
  end
end
