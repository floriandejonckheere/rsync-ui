# frozen_string_literal: true

module JobRunHelper
  JOB_RUN_STATUS_CLASSES = {
    "pending" => "text-gray-700 dark:text-gray-300",
    "running" => "text-blue-700 dark:text-blue-300",
    "completed" => "text-green-700 dark:text-green-300",
    "failed" => "text-red-700 dark:text-red-300",
    "canceled" => "text-gray-700 dark:text-gray-300",
  }.freeze

  def job_run_status_classes(status)
    JOB_RUN_STATUS_CLASSES[status]
  end

  def relative_time_tag(timestamp)
    tag.time(title: timestamp.iso8601, datetime: timestamp.iso8601) do
      relative_time_in_words(timestamp)
    end
  end
end
