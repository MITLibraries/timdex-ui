# Builds Primo links with support for discovery and NDE UIs.
#
# @example Building a search link
#   builder = PrimoLinkBuilder.new(query_term: "machine learning")
#   builder.search_link
#   # => "https://mit.primo.exlibrisgroup.com/discovery/search?query=any%2Ccontains%2Cmachine+learning&..."
#
# @example Building a full record link
#   builder = PrimoLinkBuilder.new(record_id: "alma123", context: "L")
#   builder.full_record_link
#   # => "https://mit.primo.exlibrisgroup.com/discovery/fulldisplay?docid=alma123&..."
class PrimoLinkBuilder
  # @param query_term [String, nil] The search query term (used for search_link)
  # @param record_id [String, nil] The Primo record ID (used for full_record_link)
  # @param context [String, nil] The Primo context code indicating record type:
  #   - 'L' for local catalog (Alma) records
  #   - 'PC' for CDI records
  #   - 'ALL' for all scopes
  #   See https://developers.exlibrisgroup.com/primo/apis/deep-links-new-ui/ and
  #   https://knowledge.exlibrisgroup.com/Primo/Product_Documentation/Primo/Back_Office_Guide/070Monitoring_and_Maintaining_Primo/Displaying_PNX_Records_from_Primo_Front_End
  def initialize(query_term: nil, record_id: nil, context: nil)
    @query_term = query_term
    @record_id = record_id
    @context = context
  end

  # Build a Primo search results link
  # @param tab [String] Determines which results tab to display. (default: PRIMO_TAB env var, or 'all').
  #   For detailed documentation, see primo_search model.
  # @param search_scope [String] Determines which Primo scope to search. (default: PRIMO_SCOPE env var, or 'all').
  #   For detailed documentation, see primo_search model.
  # @return [String] The complete search URL
  def search_link(tab: ENV.fetch('PRIMO_TAB', 'all'), search_scope: ENV.fetch('PRIMO_SCOPE', 'all'))
    return nil unless @query_term

    base_url = "#{ENV.fetch('MIT_PRIMO_URL')}#{search_path}?"
    params = {
      query: search_query,
      tab: tab,
      search_scope: search_scope,
      vid: vid
    }
    base_url + URI.encode_www_form(params)
  end

  # Build a Primo full record link
  # @param tab [String] Determines which results tab to display. (default: PRIMO_TAB env var, or 'all').
  #   For detailed documentation, see primo_search model.
  # @param search_scope [String] Determines which Primo scope to search. (default: PRIMO_SCOPE env var, or 'all').
  #   For detailed documentation, see primo_search model.
  # @param lang [String] The language (default: 'en')
  # @return [String] The complete full record URL, or nil if record_id or context is missing
  def full_record_link(tab: ENV.fetch('PRIMO_TAB', 'all'), search_scope: ENV.fetch('PRIMO_SCOPE', 'all'), lang: 'en')
    return nil unless @record_id && @context

    base_url = "#{ENV.fetch('MIT_PRIMO_URL')}#{full_record_path}?"
    params = {
      docid: @record_id,
      vid: vid,
      context: @context,
      search_scope: search_scope,
      lang: lang,
      tab: tab
    }
    base_url + URI.encode_www_form(params)
  end

  private

  def search_path
    Feature.enabled?(:primo_nde_links) ? '/nde/search' : '/discovery/search'
  end

  def full_record_path
    Feature.enabled?(:primo_nde_links) ? '/nde/fulldisplay' : '/discovery/fulldisplay'
  end

  def vid
    Feature.enabled?(:primo_nde_links) ? ENV.fetch('PRIMO_NDE_VID') : ENV.fetch('PRIMO_VID')
  end

  def search_query
    if Feature.enabled?(:primo_nde_links)
      @query_term
    else
      "any,contains,#{@query_term}"
    end
  end
end
