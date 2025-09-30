class Tacos
  def self.call(term)
    tacos_http = HTTP.persistent(tacos_url)
                     .headers(accept: 'application/json',
                              'Content-Type': 'application/json',
                              origin: origins)
    query = '{ "query": "{ logSearchEvent(searchTerm: \"' + clean_term(term) + '\", sourceSystem: \"' + tacos_source + '\" ) { phrase source detectors { suggestedResources { title url } } } }" }'
    raw_response = tacos_http.timeout(http_timeout).post(tacos_url, body: query)
    JSON.parse(raw_response.to_s)
  end

  private

  def self.clean_term(term)
    term.gsub('"', '\'')
  end

  def self.http_timeout
    ENV.fetch('TIMDEX_TIMEOUT', 6).to_f
  end

  def self.origins
    ENV.fetch('ORIGINS', nil)
  end

  def self.tacos_source
    ENV.fetch('TACOS_SOURCE', 'unset')
  end

  def self.tacos_url
    ENV.fetch('TACOS_URL', nil)
  end
end
