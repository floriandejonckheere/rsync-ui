# frozen_string_literal: true

class ResourceUsage < ApplicationRecord
  belongs_to :server

  enum :status, {
    ok: "ok",
    failed: "failed",
  }, validate: true

  def memory_percent
    return unless Configuration.get("resource_usage")
    return if memory_total.nil? || memory_total.to_f.zero? || memory_used.nil?

    (memory_used.to_f / memory_total * 100).round(1)
  end

  def disk_percent
    return unless Configuration.get("resource_usage")
    return if disk_total.nil? || disk_total.to_f.zero? || disk_used.nil?

    (disk_used.to_f / disk_total * 100).round(1)
  end

  def cpu_health
    return unless Configuration.get("resource_usage")
    return :unknown if cpu_usage.nil?

    critical = Configuration.get("resource_usage.cpu_critical")
    warning = Configuration.get("resource_usage.cpu_warning")

    return :critical if cpu_usage >= critical
    return :warning if cpu_usage >= warning

    :ok
  end

  def memory_health
    return :unknown unless Configuration.get("resource_usage")
    return :unknown if memory_percent.nil?

    critical = Configuration.get("resource_usage.memory_critical")
    warning = Configuration.get("resource_usage.memory_warning")

    return :critical if memory_percent >= critical
    return :warning if memory_percent >= warning

    :ok
  end

  def disk_health
    return :unknown unless Configuration.get("resource_usage")
    return :unknown if disk_percent.nil?

    critical = Configuration.get("resource_usage.disk_critical")
    warning = Configuration.get("resource_usage.disk_warning")

    return :critical if disk_percent >= critical
    return :warning if disk_percent >= warning

    :ok
  end
end

# == Schema Information
#
# Table name: resource_usages
#
#  id                  :uuid             not null, primary key
#  cpu_count           :integer
#  cpu_usage           :float
#  disk_total          :bigint
#  disk_used           :bigint
#  load_avg_1          :float
#  load_avg_15         :float
#  load_avg_5          :float
#  memory_total        :bigint
#  memory_used         :bigint
#  probe_error_class   :string
#  probe_error_message :text
#  probed_at           :datetime
#  status              :string
#  uptime_seconds      :bigint
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  server_id           :uuid             not null, uniquely indexed
#
# Indexes
#
#  index_resource_usages_on_server_id  (server_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (server_id => servers.id)
#
