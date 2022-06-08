class FactDoi
  def info(doi)
    json = fetch(doi)
    return if json == 'Error'

    {
      title: json['message']['title'],
      publisher: json['message']['publisher']
    }
  end

  def url(doi)
    "https://api.crossref.org/works/#{doi}"
  end

  def fetch(doi)
    resp = HTTP.headers(accept: 'application/json').get(url(doi))
    if resp.status == 200
      JSON.parse(resp.to_s)
    else
      Rails.logger.debug("Fact lookup error. DOI #{doi} detected but crossref returned no data")
      Rails.logger.debug("URL: #{url(doi)}")
      'Error'
    end
  end
end
