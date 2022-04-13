class TimdexWrapper
  def initialize
    @timdex_http = HTTP.headers(accept: 'application/json',
                                'Accept-Encoding': 'gzip, deflate, br',
                                'Content-Type': 'application/json',
                                Origin: 'https://lib.mit.edu')
  end

  # Run a search
  # @param term [string] The string we are searching for
  # @return [Hash] A Hash with search metadata and an Array of {Result}s
  def search(term)
    @results = @timdex_http.timeout(http_timeout)
                           .get(search_url(term))
    JSON.parse(@results.to_s)
  rescue StandardError => e
    error = {}
    error['error'] = e.to_s
    error
  end

  private

  # https://github.com/httprb/http/wiki/Timeouts
  def http_timeout
    if ENV['TIMDEX_TIMEOUT'].present?
      ENV['TIMDEX_TIMEOUT'].to_f
    else
      6
    end
  end

  def search_url(term)
    timdex_url + "search?#{QueryBuilder.new(term).querystring}"
  end

  def timdex_url
    if ENV['TIMDEX_BASE'].present?
      ENV['TIMDEX_BASE'].to_s
    else
      'https://timdex.mit.edu/api/v1/'
    end
  end
end
