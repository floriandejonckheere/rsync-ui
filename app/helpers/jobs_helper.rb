# frozen_string_literal: true

module JobsHelper
  def macos_servers(job)
    [job.source_repository&.server, job.destination_repository&.server]
      .compact
      .select(&:macos?)
      .uniq
  end

  def implied_options_data(field)
    return {} unless Job::IMPLIED_OPTIONS.key?(field)

    {
      implied_options_target: "source",
      action: "implied-options#sync",
      implies: Job::IMPLIED_OPTIONS[field].join(" "),
    }
  end
end
