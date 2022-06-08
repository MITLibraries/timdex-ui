class FactIssn
  def info(issn)
    json = fetch(issn)
    return if json == 'Error'

    {
      title: json['message']['title'],
      publisher: json['message']['publisher']
    }
  end

  def url(issn)
    "https://api.crossref.org/journals/#{issn}"
  end

  def fetch(issn)
    resp = HTTP.headers(accept: 'application/json').get(url(issn))
    if resp.status == 200
      JSON.parse(resp.to_s)
    else
      Rails.logger.debug("ISSN Lookup error. ISSN #{issn} detected but crossref returned no data")
      Rails.logger.debug("URL: #{url(issn)}")
      'Error'
    end
  end
end
