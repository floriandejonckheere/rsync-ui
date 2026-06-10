# frozen_string_literal: true

module Repositories
  class DiskSizeJob < ApplicationJob
    limits_concurrency to: 1,
                       key: ->(repository, **) { repository.id },
                       duration: 15.minutes

    def perform(repository, force: false)
      interval = Configuration.get("disk_size.interval").to_i.minutes

      return if repository.disk_size_measured_at && repository.disk_size_measured_at > interval.ago && !force

      DiskSizeService.call(repository)
    end
  end
end
