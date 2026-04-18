# frozen_string_literal: true

class JobExecutionJob < ApplicationJob
  limits_concurrency to: 1,
                     key: ->(job, **) { job.id },
                     duration: 1.hour

  def perform(job, trigger: "manual")
    JobService.new(job, trigger:).call
  end
end
