# frozen_string_literal: true

module Repositories
  class DiskSizeService < ApplicationService
    attr_reader :repository

    def initialize(repository)
      super()

      @repository = repository
    end

    def call
      disk_size = if repository.local?
                    Repositories::DiskSize::LocalService.call(repository)
                  else
                    Repositories::DiskSize::RemoteService.call(repository)
                  end

      repository.update!(
        disk_size:,
        disk_size_status: "ok",
        disk_size_error_class: nil,
        disk_size_error_message: nil,
        disk_size_measured_at: Time.current,
      )
    rescue StandardError => e
      repository.update!(
        disk_size_status: "failed",
        disk_size_error_class: e.class,
        disk_size_error_message: e.message,
        disk_size_measured_at: Time.current,
      )
    end
  end
end
