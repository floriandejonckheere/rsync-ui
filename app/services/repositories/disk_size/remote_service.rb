# frozen_string_literal: true

module Repositories
  module DiskSize
    class RemoteService < Servers::SSHService
      attr_reader :repository

      def initialize(repository)
        super(repository.server)

        @repository = repository
      end

      def call
        output = super

        kilobytes = output[/^(\d+)\s/, 1]

        raise "unparseable du output: #{output.strip}" unless kilobytes

        kilobytes.to_i * 1024
      end

      protected

      def command
        "du -sk #{Shellwords.escape(repository.path)}"
      end

      def category
        "disk_size"
      end
    end
  end
end
