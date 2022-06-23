class FactDoi
  def info(doi)
    external_data = fetch(doi)
    return if external_data == 'Error'

    metadata = extract_metadata(external_data)
    metadata[:doi] = doi
    metadata[:link_resolver_url] = link_resolver_url(metadata)
    metadata
  end

  def extract_metadata(external_data)
    {
      genre: external_data['genre'],
      title: external_data['title'],
      year: external_data['year'],
      publisher: external_data['publisher'],
      oa: external_data['is_oa'],
      oa_status: external_data['oa_status'],
      best_oa_location: external_data['best_oa_location'],
      journal_issns: external_data['journal_issns'],
      journal_name: external_data['journal_name']
    }
  end

  def url(doi)
    "https://api.unpaywall.org/v2/#{doi}?email=timdex@mit.edu"
  end

  def fetch(doi)
    resp = HTTP.headers(accept: 'application/json').get(url(doi))
    if resp.status == 200
      JSON.parse(resp.to_s)
    else
      Rails.logger.debug("Fact lookup error. DOI #{doi} detected but unpaywall returned no data")
      Rails.logger.debug("URL: #{url(doi)}")
      'Error'
    end
  end

  def link_resolver_url(metadata)
    "https://mit.primo.exlibrisgroup.com/discovery/openurl?institution=01MIT_INST&rfr_id=info:sid/mit.timdex.ui&rft.atitle=#{metadata[:title]}&rft.date=#{metadata[:year]}&rft.genre=#{metadata[:genre]}&rft.jtitle=#{metadata[:journal_name]}&rft_id=info:doi/#{metadata[:doi]}&vid=01MIT_INST:MIT"
  end
end
