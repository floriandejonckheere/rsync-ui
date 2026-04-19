# frozen_string_literal: true

FactoryBot.define do
  factory :resource_usage do
    server

    status { "ok" }

    load_avg_1 { 0.1 }
    load_avg_5 { 0.2 }
    load_avg_15 { 0.3 }

    uptime_seconds { 123_456 }

    cpu_count { 2 }
    cpu_usage { 10 }

    memory_used { 100 }
    memory_total { 200 }

    disk_used { 100 }
    disk_total { 200 }

    trait :ok do
      probed_at { 1.minute.ago }
      status { "ok" }
      probe_error_class { nil }
      probe_error_message { nil }
    end

    trait :failed do
      probed_at { 1.minute.ago }
      status { "failed" }
      probe_error_class { "Timeout::TimeoutError" }
      probe_error_message { "Connection timed out" }
    end
  end
end
