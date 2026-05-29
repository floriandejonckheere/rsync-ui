# frozen_string_literal: true

module Servers
  class CheckConnectivityTask < ApplicationTask
    def call
      Server.find_each { |server| ConnectionService.call(server) }
    end
  end
end
