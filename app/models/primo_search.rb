# Searches Primo Search API and formats results
#
class PrimoSearch

  def initialize
    validate_env
    @primo_http = HTTP.persistent(primo_api_url)
    @results = {}
  end

  def search(term, per_page)
    url = search_url(term, per_page)
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

  def primo_scope
    ENV.fetch('PRIMO_SCOPE', nil)
  end

  def primo_tab
    ENV.fetch('PRIMO_TAB', nil)
  end

  def primo_vid
    ENV.fetch('PRIMO_VID', nil)
  end

  # Initial search term sanitization
  def clean_term(term)
    term.strip.tr(' :,', '+').gsub(/\++/, '+')
  end

  # Constructs the search URL with required parameters for Primo API
  def search_url(term, per_page)
    [
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
      per_page,
      '&apikey=',
      primo_api_key
    ].join
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
