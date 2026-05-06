# frozen_string_literal: true

module Servers
  module ResourceUsage
    class HetznerService < BaseService
      protected

      def command
        "df"
      end

      private

      def parse(output)
        parse_disk(output)
      end
    end
  end
end
