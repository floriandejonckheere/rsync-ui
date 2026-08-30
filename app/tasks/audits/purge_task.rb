# frozen_string_literal: true

module Audits
  class PurgeTask < ApplicationTask
    def call # rubocop:disable Rails/Delegate
      PurgeService.call
    end
  end
end
