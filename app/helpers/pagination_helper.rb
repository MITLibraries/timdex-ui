module PaginationHelper
  def next_url(query_params)
    query_params[:page] = @pagination[:next]
    link_to results_path(query_params), 'aria-label': 'Next page' do
      'Next &raquo;'.html_safe
    end
  end

  def prev_url(query_params)
    query_params[:page] = @pagination[:prev]
    link_to results_path(query_params), 'aria-label': 'Previous page' do
      '&laquo; Previous'.html_safe
    end
  end
end
