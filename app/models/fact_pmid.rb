class FactPmid
  def info(pmid)
    xml = fetch(pmid)
    return if xml == 'Error'

    data = extract_data(xml)

    if data.reject { |_k, v| v.empty? }.present?
      data
    else
      Rails.logger.debug("Fact lookup error. PMID #{pmid} detected but ncbi returned no data")
      nil
    end
  end

  def extract_data(xml)
    {
      article_title: xml.xpath('//ArticleTitle').text,
      journal_title: xml.xpath('//Journal/Title').text,
      journal_volume: xml.xpath('//Journal/JournalIssue/Volume').text,
      journal_year: xml.xpath('//Journal/JournalIssue/PubDate/Year').text,
      pages: xml.xpath('//Article/Pagination').text,
      status: xml.xpath('//PublicationStatus').text
    }
  end

  def url(pmid)
    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=#{pmid}&retmode=xml"
  end

  def fetch(pmid)
    resp = HTTP.headers(accept: 'application/xml').get(url(pmid))

    if resp.status == 200
      Nokogiri::XML(resp.to_s)
    else
      Rails.logger.debug("Fact lookup error. PMID #{pmid} detected but ncbi an error status")
      Rails.logger.debug("URL: #{url(pmid)}")
      'Error'
    end
  end
end
