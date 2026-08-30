# frozen_string_literal: true

module Repositories
  class MeasureDiskSizeTask < ApplicationTask
    def call
      Repository.find_each { |repository| DiskSizeService.call(repository) }
    end
  end
end
