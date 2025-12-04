module ResultsHelper
  def results_summary(hits)
    hits.to_i >= 10_000 ? '10,000+ results' : "#{number_with_delimiter(hits)} results"
  end

  # Provides a description for the current tab in search results.
  def tab_description
    case params[:tab]
    when 'all'
      'All MIT Libraries sources'
    when 'cdi'
      'Journal and newspaper articles, book chapters, and more'
    when 'alma', 'timdex_alma'
      'Books, journals, streaming and physical media, and more'
    when 'primo'
      'Articles, books, chapters, streaming and physical media, and more'
    when 'aspace'
      'Archives, manuscripts, and other unique materials related to MIT'
    when 'timdex'
      'Digital collections, images, documents, and more from MIT Libraries'
    when 'website'
      'Information about the library: events, news, services, and more'
    else
      Rails.logger.error "Unknown tab parameter in `tab_description` helper: #{params[:tab]}"
    end
  end
end
