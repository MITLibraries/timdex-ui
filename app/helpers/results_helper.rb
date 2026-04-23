module ResultsHelper
  # Descriptions for each tab. HTML entries use raw anchor tags (all URLs are
  # hardcoded external links, so no XSS risk) and must be marked html_safe.
  TAB_DESCRIPTIONS = {
    'all' => 'All MIT Libraries sources',
    'cdi' => 'Journal and newspaper articles, book reviews, book chapters, and more',
    'alma' => 'Books, e-books, journals, streaming and physical media, and more',
    'timdex_alma' => 'Books, e-books, journals, streaming and physical media, and more',
    'primo' => 'Articles, books, chapters, streaming and physical media, and more',
    'aspace' => 'Archives, manuscripts, and other unique materials related to MIT',
    'timdex' => 'Digital collections, images, documents, and more from MIT Libraries',
    'website' => 'Information about the library: events, news, services, and more',
    'dspace' => '<a href="https://dspace.mit.edu">DSpace@MIT</a> ' \
                "is a digital repository for MIT's research, including peer-reviewed articles, " \
                'technical reports, working papers, theses, and more.'.html_safe,
    'geodata' => "Geospatial datasets and maps from MIT Libraries' " \
                 '<a href="https://geodata.libraries.mit.edu">GeoData</a> collections; ' \
                 'includes <a href="https://opengeometadata.org">Open Geospatial Consortium (OGC)</a> data.'.html_safe,
    'databases' => '<a href="https://libguides.mit.edu/az/databases">Research Databases</a> ' \
                   'covering a wide range of subjects and formats'.html_safe
  }.freeze

  def results_summary(hits)
    hits.to_i >= 10_000 ? '10,000+ results' : "#{number_with_delimiter(hits)} results"
  end

  # Provides a description for the current tab in search results.
  def tab_description
    TAB_DESCRIPTIONS.fetch(params[:tab]) do
      Rails.logger.error "Unknown tab parameter in `tab_description` helper: #{params[:tab]}"
      ''
    end
  end

  # Creates Primo UI links based on current search term
  #
  # Examples from UI we are targeting:
  #  - https://mit.primo.exlibrisgroup.com/discovery/search?query=any,contains,breakfast%20of%20champions&tab=all&search_scope=bento_catalog&vid=01MIT_INST:MIT
  #  - https://mit.primo.exlibrisgroup.com/discovery/search?query=any,contains,breakfast%20of%20champions&tab=all&search_scope=cdi&vid=01MIT_INST:MIT
  #  - https://mit.primo.exlibrisgroup.com/nde/search?query=breakfast%20of%20champions&tab=all&search_scope=all&vid=01MIT_INST:NDE
  def search_primo_link
    PrimoLinkBuilder.new(query_term: params[:q]).search_link
  end

  # Creates MIT ArchivesSpace links based on current search term
  #
  # Examples from UI we are targeting:
  # - https://archivesspace.mit.edu/search?op%5B%5D=&q%5B%5D=minutes
  # - https://archivesspace.mit.edu/search?utf8=✓&op%5B%5D=&q%5B%5D=minutes&limit=&field%5B%5D=&from_year%5B%5D=&to_year%5B%5D=&commit=Search
  def search_aspace_link
    aspace_params = URI.encode_www_form({
                                          'q[]': params[:q],
                                          utf8: '✓',
                                          'op[]': ''
                                        })

    'https://archivesspace.mit.edu/search?' + aspace_params
  end

  # Creates WorldCat links based on current search term
  def search_worldcat_link
    worldcat_params = URI.encode_www_form({
                                            queryString: params[:q]
                                          })

    'https://mit.on.worldcat.org/search?' + worldcat_params
  end
end
