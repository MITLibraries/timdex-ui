class Tacos
  # The tacos_client argument here is unused in production - it is provided for
  # our test suite so that we can mock various error conditions to ensure that
  # error handling happens as we intend.
  def self.analyze(term, tacos_client = nil)
    tacos_http = setup(tacos_client)
    query = '{ "query": "{ logSearchEvent(searchTerm: \"' + clean_term(term) + '\", sourceSystem: \"' + tacos_source + '\" ) { phrase source detectors { suggestedResources { title url } } } }" }'
    begin
      raw_response = tacos_http.timeout(http_timeout).post(tacos_url, body: query)
      JSON.parse(raw_response.to_s)
    rescue HTTP::Error
      {"error" => "A connection error has occurred"}
    rescue JSON::ParserError
      {"error" => "A parsing error has occurred"}
    end
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

  # We define the HTTP connection this way so that it can be overridden during
  # testing, to make sure that the .analyze method can handle specific error
  # conditions.
  def self.setup(tacos_client)
    tacos_client || HTTP.persistent(tacos_url)
                        .headers(accept: 'application/json',
                                 'Content-Type': 'application/json',
                                 origin: origins)
  end

  def self.tacos_source
    ENV.fetch('TACOS_SOURCE', 'timdexui_unset')
  end

  def self.tacos_url
    ENV.fetch('TACOS_URL', nil)
  end
end
