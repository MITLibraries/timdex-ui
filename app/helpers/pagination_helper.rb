module PaginationHelper
  def next_url(query_params)
    query_params[:page] = @pagination[:next]
    link_to results_path(query_params), class: 'btn button-primary' do
      "Next page #{content_tag(:span, '', class: 'fa fa-chevron-right')}".html_safe
    end
  end

  def prev_url(query_params)
    query_params[:page] = @pagination[:prev]
    link_to results_path(query_params), class: 'btn button-primary' do
      "#{content_tag(:span, '', class: 'fa fa-chevron-left')} Previous page".html_safe
    end
  end
end
