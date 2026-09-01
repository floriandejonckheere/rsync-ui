# frozen_string_literal: true

module JobsHelper
  def macos_servers(job)
    [job.source_repository&.server, job.destination_repository&.server]
      .compact
      .select(&:macos?)
      .uniq
  end
end
