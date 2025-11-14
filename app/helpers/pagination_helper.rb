module PaginationHelper
  def first_url(query_params)
    # Work with a copy to avoid mutating the original enhanced_query.
    params_copy = query_params.dup
    params_copy[:page] = 1

    # Preserve the active tab in pagination URLs.
    params_copy[:tab] = @active_tab if @active_tab.present?

    # First page gets a disabled link in a span
    # Check the original, not copied params to determine if we need a disabled link
    if query_params[:page].blank? || query_params[:page].to_i == 1
      '<span role="link" aria-disabled="true" tabindex="-1">First</span>'.html_safe
    else
      link_to results_path(params_copy), 'aria-label': 'First',
                                         data: { turbo_frame: 'search-results', turbo_action: 'advance' },
                                         rel: 'nofollow' do
        'First'.html_safe
      end
    end
  end

  def next_url(query_params)
    # Work with a copy to avoid mutating the original enhanced_query.
    params_copy = query_params.dup
    params_copy[:page] = @pagination[:next]

    # Preserve the active tab in pagination URLs.
    params_copy[:tab] = @active_tab if @active_tab.present?

    if remaining_results <= 0
      "<span role='link' aria-disabled='true' tabindex='-1'>#{next_page_label}</span>".html_safe
    else
      link_to results_path(params_copy), 'aria-label': next_page_label,
                                         data: { turbo_frame: 'search-results', turbo_action: 'advance' },
                                         rel: 'nofollow' do
        next_page_label.html_safe
      end
    end
  end

  # Calculate how many results remain after the current end index
  def remaining_results
    @pagination[:hits] - @pagination[:end]
  end

  def next_page_label
    label = if (@pagination[:end] + @pagination[:per_page]) < @pagination[:hits]
              @pagination[:per_page]
            else
              remaining_results
            end

    "Next #{label} results"
  end

  def prev_url(query_params)
    # Work with a copy to avoid mutating the original enhanced_query.
    params_copy = query_params.dup
    params_copy[:page] = @pagination[:prev]

    # Preserve the active tab in pagination URLs.
    params_copy[:tab] = @active_tab if @active_tab.present?

    # First page gets a disabled link in a span
    if query_params[:page].blank? || query_params[:page].to_i == 1
      "<span role='link' aria-disabled='true' tabindex='-1'>#{prev_page_label}</span>".html_safe
    else
      link_to results_path(params_copy), 'aria-label': prev_page_label,
                                         data: { turbo_frame: 'search-results', turbo_action: 'advance' },
                                         rel: 'nofollow' do
        prev_page_label.html_safe
      end
    end
  end

  def prev_page_label
    'Previous 20 results'
  end
end
