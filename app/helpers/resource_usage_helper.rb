# frozen_string_literal: true

module ResourceUsageHelper
  RESOURCE_BAR_COLORS = {
    critical: {
      bar: "bg-red-600 dark:bg-red-400",
      track: "bg-red-100 dark:bg-red-950",
    },
    warning: {
      bar: "bg-amber-500 dark:bg-amber-400",
      track: "bg-amber-100 dark:bg-amber-950",
    },
    ok: {
      bar: "bg-blue-600 dark:bg-blue-400",
      track: "bg-blue-100 dark:bg-blue-950",
    },
  }.freeze

  def resource_bar_color(health)
    RESOURCE_BAR_COLORS.fetch(health, RESOURCE_BAR_COLORS[:ok])
  end

  def resource_bar_tooltip(resource_usage, metric)
    return unless resource_usage

    case metric
    when :disk
      return if resource_usage.disk_used.blank?

      "#{number_to_human_size(resource_usage.disk_used)} / #{number_to_human_size(resource_usage.disk_total)}"
    when :memory
      return if resource_usage.memory_used.blank?

      "#{number_to_human_size(resource_usage.memory_used)} / #{number_to_human_size(resource_usage.memory_total)}"
    when :cpu
      return if resource_usage.cpu_count.blank?

      t("servers.table.cpu_cores", count: resource_usage.cpu_count)
    end
  end
end
