# frozen_string_literal: true

module PaginationHelper
  def pagination_page_path(path_method, page_number, **params)
    send(path_method, **params, page: page_number)
  end
end
