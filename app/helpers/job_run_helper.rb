# frozen_string_literal: true

module JobRunHelper
  JOB_RUN_STATUS_CLASSES = {
    "pending" => "bg-gray-50 dark:bg-gray-700 text-gray-700 dark:text-gray-300",
    "running" => "bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300",
    "completed" => "bg-green-50 dark:bg-green-900/30 text-green-700 dark:text-green-300",
    "failed" => "bg-red-50 dark:bg-red-900/30 text-red-700 dark:text-red-300",
    "canceled" => "bg-gray-50 dark:bg-gray-700 text-gray-700 dark:text-gray-300",
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
