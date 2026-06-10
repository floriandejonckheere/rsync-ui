# frozen_string_literal: true

module Repositories
  module DiskSize
    class LocalService < ApplicationService
      attr_reader :repository

      def initialize(repository)
        super()

        @repository = repository
      end

      def call
        stdout, stderr, status = Open3.capture3("du", "-sk", repository.path)

        raise "du failed: #{stderr.strip}" unless status.success?

        kilobytes = stdout[/\A(\d+)\s/, 1]

        raise "unparseable du output: #{stdout.strip}" unless kilobytes

        kilobytes.to_i * 1024
      end
    end
  end
end
