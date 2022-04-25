class TimdexWrapper
  attr_reader :results

  def initialize
    @timdex = HTTP.headers(accept: 'application/json',
                           'Accept-Encoding': 'gzip, deflate, br',
                           'Content-Type': 'application/json',
                           Origin: ENV.fetch('TIMDEX-UI-ORIGIN', 'http://localhost:3000'))
  end

  # Run a search
  # @param query [Hash] The output of the QueryBuilder
  # @return [Hash] A Hash with search metadata and an Array of {Result}s
  def search(query)
    @results = @timdex.timeout(http_timeout)
                      .get(search_url(query))
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

  def search_url(query)
    timdex_url + "search?#{query.to_query}"
  end

  def timdex_url
    if ENV['TIMDEX_BASE'].present?
      ENV['TIMDEX_BASE'].to_s
    else
      'https://timdex.mit.edu/api/v1/'
    end
  end
end
