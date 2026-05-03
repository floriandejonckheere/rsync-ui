# frozen_string_literal: true

module Hooks
  class ExportService < ::ExportService
    private

    def csv_filename
      "08_hooks.csv"
    end

    def headers = ["hook_type", "command", "arguments", "enabled", "job_name", "user_email"]

    def rows
      Hook.all.map do |hook|
        [
          hook.hook_type,
          hook.command,
          hook.arguments,
          hook.enabled,
          hook.job.name,
          hook.job.user.email,
        ]
      end
    end
  end
end
