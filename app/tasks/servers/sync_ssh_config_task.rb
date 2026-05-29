# frozen_string_literal: true

module Servers
  class SyncSSHConfigTask < ApplicationTask
    def call # rubocop:disable Rails/Delegate
      Servers::SSHConfigService.call
    end
  end
end
