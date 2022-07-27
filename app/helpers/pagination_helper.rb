module PaginationHelper
  def next_url(query_params)
    query_params[:page] = @pagination[:next]
    link_to results_path(query_params), class: 'btn button-primary' do
      t('search.pagination.next_page').html_safe + content_tag(:span, '', class: 'fa fa-chevron-right').html_safe
    end
  end

  def prev_url(query_params)
    query_params[:page] = @pagination[:prev]
    link_to results_path(query_params), class: 'btn button-primary' do
      content_tag(:span, '', class: 'fa fa-chevron-left').html_safe + t('search.pagination.prev_page').html_safe
    end
  end
end
