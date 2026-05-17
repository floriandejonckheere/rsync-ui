# frozen_string_literal: true

module ApplicationHelper
  def server_link(server, absolute_url: false)
    return if server.blank?

    url  = absolute_url ? edit_server_url(server) : edit_server_path(server)
    data = {
      turbo_frame: "_top",
      tooltip: server.description.presence,
    }.compact_blank

    link_to(
      server.name,
      url,
      class: "hover:underline",
      title: server.description.presence,
      data:,
    )
  end

  def on_server_tag(server, absolute_url: false)
    return if server.blank?

    tag.span(class: "text-xs text-gray-400 dark:text-gray-500") do
      t("jobs.table.on_server_html", server_html: server_link(server, absolute_url:))
    end
  end

  def on_server_label(server)
    return if server.blank?

    tag.span(class: "text-xs text-gray-400 dark:text-gray-500") do
      " #{I18n.t('jobs.table.on_server', server: server.name)}"
    end
  end
end
