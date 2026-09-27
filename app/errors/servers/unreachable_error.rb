# frozen_string_literal: true

module Servers
  class UnreachableError < ApplicationError
    def initialize(**context)
      super("servers.unreachable", **context)
    end
  end
end
