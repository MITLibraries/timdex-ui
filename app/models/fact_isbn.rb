class FactIsbn
  def info(isbn)
    json = fetch(isbn)
    return if json == 'Error'

    {
      title: json['title'],
      publish_date: json['publish_date'],
      publishers: json['publishers']
    }
  end

  def url(isbn)
    "https://openlibrary.org/isbn/#{isbn}.json"
  end

  def fetch(isbn)
    resp = HTTP.headers(accept: 'application/json', 'Content-Type': 'application/json').follow.get(url(isbn))

    if resp.status == 200
      JSON.parse(resp.to_s)
    else
      Rails.logger.debug("Fact lookup error. ISBN #{isbn} detected but openlibrary returned no data")
      Rails.logger.debug("URL: #{url(isbn)}")
      'Error'
    end
  end
end
