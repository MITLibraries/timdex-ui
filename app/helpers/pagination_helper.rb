module PaginationHelper
  def next_url(query_params)
    query_params[:page] = @pagination[:next]
    link_to('Next page', results_path(query_params))
  end

  def prev_url(query_params)
    query_params[:page] = @pagination[:prev]
    link_to('Previous page', results_path(query_params))
  end
end
