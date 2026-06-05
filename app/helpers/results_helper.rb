module ResultsHelper
  # Descriptions for each tab. HTML entries use raw anchor tags (all URLs are
  # hardcoded external links, so no XSS risk) and must be marked html_safe.
  TAB_DESCRIPTIONS = {
    'all' => 'Search across all MIT Libraries systems',
    'cdi' => 'Articles, reviews, book chapters, and more from ' \
             '<a href="https://mit.primo.exlibrisgroup.com/discovery/search?vid=01MIT_INST:MIT&lang=en">' \
             'Articles, Books & More</a>'.html_safe,
    'alma' => 'Books, e-books, journals, streaming and physical media, and more from ' \
              '<a href="https://mit.primo.exlibrisgroup.com/discovery/search?vid=01MIT_INST:MIT&lang=en">' \
              'Articles, Books & More</a>'.html_safe,
    'timdex_alma' => 'Books, e-books, journals, streaming and physical media, and more',
    'primo' => 'Articles, books, chapters, streaming and physical media, and more',
    'aspace' => 'Finding aids for archival and unique primary source materials at MIT from ' \
                '<a href="https://archivesspace.mit.edu">Archives & Manuscripts</a>'.html_safe,
    'timdex' => 'Digital collections, images, documents, and more from MIT Libraries',
    'website' => 'Events, news, services, and research guides from the ' \
                 '<a href="https://libraries.mit.edu">Library Website</a> and ' \
                 '<a href="https://libraries.mit.edu/experts/">Research Guides</a>'.html_safe,
    'dspace' => 'Peer-reviewed articles, theses and dissertations, technical reports, and more from ' \
                '<a href="https://dspace.mit.edu">MIT Open Scholarship</a> '.html_safe,
    'geodata' => 'Shape files, raster data, and more from ' \
                 '<a href="https://geodata.libraries.mit.edu">MIT Geospatial Data</a>'.html_safe,
    'databases' => 'Indexes, full-text archives, data sources, and other specialized search tools from ' \
                   '<a href="https://libguides.mit.edu/az/databases">Research Databases</a>'.html_safe
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

  # Determines if a format value represents an article type
  #
  # @param format [String] The format value to check (e.g., 'Article', 'Magazine Article')
  # @return [Boolean] True if format contains 'article' as a whole word (case-insensitive), false otherwise
  def article?(format)
    return false if format.blank?

    format.match?(/\barticle\b/i)
  end

  # Determines if a result has any fulfillment links to render
  #
  # @param result [Hash] A normalized Primo result hash
  # @return [Boolean] True if the result has links, availability, or ThirdIron/OpenAlex triggers
  def result_get?(result)
    has_renderable_links?(result) ||
      result[:availability].present? ||
      (Feature.enabled?(:oa_always) && article?(result[:format])) ||
      has_thirdiron_content?(result)
  end

  private

  def has_renderable_links?(result)
    return false unless result[:links].present?
    return true if Feature.enabled?(:record_link)

    # If record_link is disabled, exclude results that have ONLY "full record" links
    result[:links].any? { |link| link['kind'].downcase != 'full record' }
  end

  def has_thirdiron_content?(result)
    ThirdIron.enabled? && (
      result[:doi].present? ||
      result[:pmid].present? ||
      (result[:format]&.downcase == 'journal' && result[:issn].present?)
    )
  end
end
