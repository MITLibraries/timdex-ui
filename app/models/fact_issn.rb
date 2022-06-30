class FactIssn
  def info(issn)
    return unless validate(issn)

    json = fetch(issn)
    return if json == 'Error'

    metadata = extract_metadata(json)
    metadata[:openurl] = openurl(issn)
    metadata
  end

  def extract_metadata(response)
    {
      title: response['message']['title'],
      publisher: response['message']['publisher']
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

  def openurl(issn)
    "https://mit.primo.exlibrisgroup.com/discovery/openurl?institution=01MIT_INST&rfr_id=info:sid/mit.timdex.ui&rft.issn=#{issn}&vid=01MIT_INST:MIT"
  end

  def validate(candidate)
    # This model is only called when the regex for an ISSN has indicated an ISSN
    # of sufficient format is present - but the regex does not attempt to
    # validate that the check digit in the ISSN spec is correct. This method
    # does that calculation, so we can avoid sending nonsense requests to
    # CrossRef or the Primo API for facially-valid ISSNs that actually are not,
    # like "2015-2019".
    #
    # The algorithm is defined at
    # https://datatracker.ietf.org/doc/html/rfc3044#section-2.2
    # An example calculation is shared at
    # https://en.wikipedia.org/wiki/International_Standard_Serial_Number#Code_format
    digits = candidate.gsub('-', '').chars[..6]
    check_digit = candidate.last.downcase
    sum = 0
    digits.each_with_index do |digit, idx|
      sum += digit.to_i * (8 - idx.to_i)
    end
    actual_digit = 11 - sum.modulo(11)
    actual_digit = 'x' if actual_digit == 10
    return true if actual_digit.to_s == check_digit.to_s

    false
  end
end
