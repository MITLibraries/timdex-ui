class FactIsbn
  def info(isbn)
    json = fetch_isbn(isbn)
    return if json == 'Error'

    {
      title: json['title'],
      publish_date: json['publish_date'],
      publishers: json['publishers'],
      author_names: fetch_authors(json),
      openurl: link_resolver_url(isbn)
    }
  end

  def base_url
    'https://openlibrary.org'
  end

  def fetch_isbn(isbn)
    url = [base_url, "/isbn/#{isbn}.json"].join
    parse_response(url)
  end

  def fetch_authors(isbn_json)
    return unless isbn_json['authors']

    authors = isbn_json['authors'].map { |a| a['key'] }
    author_names = authors.map do |author|
      url = [base_url, author, '.json'].join
      json = parse_response(url)
      json['name']
    end
    author_names.join(' ; ')
  end

  def parse_response(url)
    resp = HTTP.headers(accept: 'application/json', 'Content-Type': 'application/json').follow.get(url)

    if resp.status == 200
      JSON.parse(resp.to_s)
    else
      Rails.logger.debug('Fact lookup error: openlibrary returned no data')
      Rails.logger.debug("URL: #{url}")
      'Error'
    end
  end

  def link_resolver_url(isbn)
    "https://mit.primo.exlibrisgroup.com/discovery/openurl?institution=01MIT_INST&vid=01MIT_INST:MIT&rft.isbn=#{isbn}"
  end
end
