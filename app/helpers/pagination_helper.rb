module PaginationHelper
  def first_url(query_params)
    # Work with a copy to avoid mutating the original enhanced_query.
    params_copy = query_params.dup
    params_copy[:page] = 1

    # Preserve the active tab in pagination URLs.
    params_copy[:tab] = @active_tab if @active_tab.present?

    link_to results_path(params_copy), 'aria-label': 'First page',
                                       data: { turbo_frame: 'search-results', turbo_action: 'advance' },
                                       rel: 'nofollow' do
      '&laquo;&laquo; First'.html_safe
    end
  end

  def next_url(query_params)
    # Work with a copy to avoid mutating the original enhanced_query.
    params_copy = query_params.dup
    params_copy[:page] = @pagination[:next]

    # Preserve the active tab in pagination URLs.
    params_copy[:tab] = @active_tab if @active_tab.present?

    link_to results_path(params_copy), 'aria-label': 'Next page',
                                       data: { turbo_frame: 'search-results', turbo_action: 'advance' },
                                       rel: 'nofollow' do
      'Next &raquo;'.html_safe
    end
  end

  def prev_url(query_params)
    # Work with a copy to avoid mutating the original enhanced_query.
    params_copy = query_params.dup
    params_copy[:page] = @pagination[:prev]

    # Preserve the active tab in pagination URLs.
    params_copy[:tab] = @active_tab if @active_tab.present?

    link_to results_path(params_copy), 'aria-label': 'Previous page',
                                       data: { turbo_frame: 'search-results', turbo_action: 'advance' },
                                       rel: 'nofollow' do
      '&laquo; Previous'.html_safe
    end
  end
end
