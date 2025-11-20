# Searches Primo Search API and formats results
#
class PrimoSearch
  # Initializes PrimoSearch
  # @param tab [String] Current `active_tab` value from SearchController. Used to set Primo tab/scope.
  #   Defaults to 'all'.
  # @return [PrimoSearch] An instance of PrimoSearch
  def initialize(tab = 'all')
    @tab = tab

    validate_env
    @primo_http = HTTP.persistent(primo_api_url)
    @results = {}
  end

  # Performs a search against the Primo API
  # @param term [String] The search term
  # @param per_page [Integer] Number of results per page
  # @param offset [Integer] The result offset for pagination
  # @return [Hash] Parsed JSON response from Primo API
  def search(term, per_page, offset = 0)
    url = search_url(term, per_page, offset)
    result = @primo_http.timeout(http_timeout)
                        .headers(
                          accept: 'application/json',
                          Authorization: "apikey #{primo_api_key}"
                        )
                        .get(url)

    raise "Primo Error Detected: #{result.status}" unless result.status == 200

    JSON.parse(result)
  end

  private

  def validate_env
    missing_vars = []

    missing_vars << 'PRIMO_API_URL' if primo_api_url.nil?
    missing_vars << 'PRIMO_API_KEY' if primo_api_key.nil?
    missing_vars << 'PRIMO_SCOPE' if primo_scope.nil?
    missing_vars << 'PRIMO_TAB' if primo_tab.nil?
    missing_vars << 'PRIMO_VID' if primo_vid.nil?

    return if missing_vars.empty?

    raise ArgumentError, "Required Primo environment variables are not set: #{missing_vars.join(', ')}"
  end

  # Environment variable accessors
  def primo_api_url
    ENV.fetch('PRIMO_API_URL', nil)
  end

  def primo_api_key
    ENV.fetch('PRIMO_API_KEY', nil)
  end

  # In Primo API, Search scopes determines which records are being searched
  # Primo VE configuration calls this `Search Profiles` and uses `Scope` differently.
  # For Primo VE API we want to be doing &scope={Primo VE Search Profile}
  #
  # Available scopes for USE
  #   all_use: includes CDI configured like Primo UI + Alma (does not include ASpace)
  #   all: same as all_use but includes ASpace
  #   catalog_use: just Alma
  #   cdi_use: just CDI configured like Primo UI
  #
  # The scope we use will be driven by the tab provided during initialization
  def primo_scope
    case @tab
    when 'cdi'
      'cdi_use'
    when 'alma'
      'catalog_use'
    else
      'all_use'
    end
  end

  # In Primo, Tabs act as "search scope slots". They contain one or more Search Profile (which Primo API calls `scopes`).
  # Primo VE configuration refers to these as `Search Profile Slots`
  # Configured tabs in our Primo
  #   all: scopes(all, all_filtered, catalog, cdi, CourseReserves)
  #   bento: scopes(cdi, catalog, bento_catalog, all_use)
  #   USE: scopes(all_use, all, catalog_use, cdi_use)
  #   This application should always use the 'use' tab for Primo searches.
  def primo_tab
    'use'
  end

  # In Primo API, a view (vid) contains Search Profile Slots (tabs) which in turn contain Search Profiles (scopes).
  def primo_vid
    ENV.fetch('PRIMO_VID', nil)
  end

  # Initial search term sanitization
  def clean_term(term)
    term.strip.tr(' :,', '+').gsub(/\++/, '+')
  end

  # Constructs the search URL with required parameters for Primo API
  def search_url(term, per_page, offset = 0)
    url_parts = [
      primo_api_url,
      '/search?q=any,contains,',
      clean_term(term),
      '&vid=',
      primo_vid,
      '&tab=',
      primo_tab,
      '&scope=',
      primo_scope,
      '&limit=',
      per_page
    ]

    # Add offset parameter for pagination (only if > 0)
    url_parts += ['&offset=', offset] if offset > 0

    url_parts += [
      '&apikey=',
      primo_api_key
    ]

    url_parts.join
  end

  # Timeout configuration for HTTP requests
  def http_timeout
    if ENV.fetch('PRIMO_TIMEOUT', nil).present?
      ENV['PRIMO_TIMEOUT'].to_f
    else
      6
    end
  end
end
