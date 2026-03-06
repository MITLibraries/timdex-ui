# Builds Primo links with support for standard and NDE UIs.
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
  def initialize(query_term: nil, record_id: nil, context: nil)
    @query_term = query_term
    @record_id = record_id
    @context = context
  end

  # Build a Primo search results link
  # @param tab [String] The Primo tab parameter (default: 'all')
  # @param search_scope [String] The search scope (default: 'all')
  # @return [String] The complete search URL
  def search_link(tab: 'all', search_scope: 'all')
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
  # @param tab [String] The Primo tab parameter (default: PRIMO_TAB env var)
  # @param search_scope [String] The search scope (default: 'all')
  # @param lang [String] The language (default: 'en')
  # @return [String] The complete full record URL, or nil if record_id or context is missing
  def full_record_link(tab: ENV.fetch('PRIMO_TAB'), search_scope: 'all', lang: 'en')
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
