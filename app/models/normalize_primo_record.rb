# Transforms a Primo Search API result into a normalized record.
class NormalizePrimoRecord
  def initialize(record, query)
    @record = record
    @query = query
  end

  def normalize
    {
      # Core fields
      title:,
      creators:,
      source:,
      year:,
      format:,
      links:,
      citation:,
      identifier:,
      summary:,
      publisher:,
      location:,
      subjects:,
      # Primo-specific fields
      container:,
      numbering:,
      chapter_numbering:,
      thumbnail:,
      availability:,
      other_availability:
    }
  end

  private

  def title
    if @record['pnx']['display']['title'].present?
      @record['pnx']['display']['title'].join
    else
      'unknown title'
    end
  end

  def creators
    return [] unless @record['pnx']['display']['creator'] || @record['pnx']['display']['contributor']

    author_list = []

    if @record['pnx']['display']['creator']
      creators = sanitize_authors(@record['pnx']['display']['creator'])
      creators.each do |creator|
        author_list << { value: creator, link: author_link(creator) }
      end
    end

    if @record['pnx']['display']['contributor']
      contributors = sanitize_authors(@record['pnx']['display']['contributor'])
      contributors.each do |contributor|
        author_list << { value: contributor, link: author_link(contributor) }
      end
    end

    author_list.uniq
  end

  def source
    'Primo'
  end

  def year
    if @record['pnx']['display']['creationdate'].present?
      @record['pnx']['display']['creationdate'].join
    else
      return unless @record['pnx']['search'] && @record['pnx']['search']['creationdate']

      @record['pnx']['search']['creationdate'].join
    end
  end

  def format
    return unless @record['pnx']['display']['type']

    normalize_type(@record['pnx']['display']['type'].join)
  end

  # While the links object in the Primo response often contains more than the Alma openurl, that is
  # the one that is most predictably useful to us. The record_link is constructed.
  def links
    links = []

    # Use dedup URL as the full record link if available, otherwise use record link
    if dedup_url.present?
      links << { 'url' => dedup_url, 'kind' => 'full record' }
    elsif record_link.present?
      links << { 'url' => record_link, 'kind' => 'full record' }
    end

    # Add openurl if available
    links << { 'url' => openurl, 'kind' => 'openurl' } if openurl.present?

    # Return links if we found any
    links.any? ? links : []
  end

  def citation
    return unless @record['pnx']['addata']

    if @record['pnx']['addata']['volume'].present?
      if @record['pnx']['addata']['issue'].present?
        "volume #{@record['pnx']['addata']['volume'].join} issue #{@record['pnx']['addata']['issue'].join}"
      else
        "volume #{@record['pnx']['addata']['volume'].join}"
      end
    elsif @record['pnx']['addata']['date'].present? && @record['pnx']['addata']['pages'].present?
      "#{@record['pnx']['addata']['date'].join}, pp. #{@record['pnx']['addata']['pages'].join}"
    end
  end

  def container
    return unless @record['pnx']['addata']

    if @record['pnx']['addata']['jtitle'].present?
      @record['pnx']['addata']['jtitle'].join
    elsif @record['pnx']['addata']['btitle'].present?
      @record['pnx']['addata']['btitle'].join
    end
  end

  def identifier
    return unless @record['pnx']['control']['recordid']

    @record['pnx']['control']['recordid'].join
  end

  def summary
    return unless @record['pnx']['display']['description']

    @record['pnx']['display']['description'].join(' ')
  end

  # This constructs a link to the record in Primo.
  #
  # We've altered this method slightly to address bugs introduced in the Primo VE November 2021
  # release. The search_scope param is now required for CDI fulldisplay links, and the context param
  # is now required for local (catalog) fulldisplay links.
  #
  # In order to avoid more surprises, we're adding all of the params included in the fulldisplay
  # example links provided here, even though not all of them are actually required at present:
  # https://developers.exlibrisgroup.com/primo/apis/deep-links-new-ui/
  #
  # We should keep an eye on this over subsequent Primo reeleases and revert it to something more
  # minimalist/sensible when Ex Libris fixes this issue.
  def record_link
    return unless @record['pnx']['control']['recordid']
    return unless @record['context']

    record_id = @record['pnx']['control']['recordid'].join
    base = [ENV.fetch('MIT_PRIMO_URL'), '/discovery/fulldisplay?'].join
    query = {
      docid: record_id,
      vid: ENV.fetch('PRIMO_VID'),
      context: @record['context'],
      search_scope: 'all',
      lang: 'en',
      tab: ENV.fetch('PRIMO_TAB')
    }.to_query
    [base, query].join
  end

  def numbering
    return unless @record['pnx']['addata']
    return unless @record['pnx']['addata']['volume']

    if @record['pnx']['addata']['issue'].present?
      "volume #{@record['pnx']['addata']['volume'].join} issue #{@record['pnx']['addata']['issue'].join}"
    else
      "volume #{@record['pnx']['addata']['volume'].join}"
    end
  end

  def chapter_numbering
    return unless @record['pnx']['addata']
    return unless @record['pnx']['addata']['btitle']
    return unless @record['pnx']['addata']['date'] && @record['pnx']['addata']['pages']

    "#{@record['pnx']['addata']['date'].join}, pp. #{@record['pnx']['addata']['pages'].join}"
  end

  def sanitize_authors(authors)
    authors.map! { |author| author.split(';') }.flatten! if authors.any? { |author| author.include?(';') }
    authors.map { |author| author.strip.gsub(/\$\$Q.*$/, '') }
  end

  def author_link(author)
    [ENV.fetch('MIT_PRIMO_URL'),
     '/discovery/search?query=creator,exact,',
     encode_author(author),
     '&tab=', ENV.fetch('PRIMO_TAB'),
     '&search_scope=all&vid=',
     ENV.fetch('PRIMO_VID')].join
  end

  def encode_author(author)
    URI.encode_uri_component(author)
  end

  def normalize_type(type)
    r_types = {
      'BKSE' => 'eBook',
      'reference_entry' => 'Reference Entry',
      'Book_chapter' => 'Book Chapter'
    }
    r_types[type] || type.capitalize
  end

  # It's possible we'll encounter records that use a different server,
  # so we want to test against our expected server to guard against
  # malformed URLs. This assumes all URL strings begin with https://.
  def openurl
    return unless @record['delivery'] && @record['delivery']['almaOpenurl']

    # Check server match
    openurl_server = ENV.fetch('ALMA_OPENURL', nil)[8, 4]
    record_openurl_server = @record['delivery']['almaOpenurl'][8, 4]
    if openurl_server == record_openurl_server
      construct_primo_openurl
    else
      Rails.logger.warn "Alma openurl server mismatch. Expected #{openurl_server}, but received #{record_openurl_server}. (record ID: #{identifier})"
      @record['delivery']['almaOpenurl']
    end
  end

  def construct_primo_openurl
    return unless @record['delivery']['almaOpenurl']

    # Here we are converting the Alma link resolver URL provided by the Primo
    # Search API to redirect to the Primo UI. This is done for UX purposes,
    # as the regular Alma link resolver URLs redirect to a plaintext
    # disambiguation page.
    primo_openurl_base = [ENV.fetch('MIT_PRIMO_URL', nil),
                          '/discovery/openurl?institution=',
                          ENV.fetch('EXL_INST_ID', nil),
                          '&vid=',
                          ENV.fetch('PRIMO_VID', nil),
                          '&'].join
    primo_openurl = @record['delivery']['almaOpenurl'].gsub(ENV.fetch('ALMA_OPENURL', nil), primo_openurl_base)

    # The ctx params appear to break Primo openurls, so we need to remove them.
    params = Rack::Utils.parse_nested_query(primo_openurl)
    filtered = params.delete_if { |key, _value| key.starts_with?('ctx') }
    URI::DEFAULT_PARSER.unescape(filtered.to_param)
  end

  def thumbnail
    return unless @record['pnx']['addata'] && @record['pnx']['addata']['isbn']

    # A record can have multiple ISBNs, so we are assuming here that
    # the thumbnail URL can be constructed from the first occurrence
    isbn = @record['pnx']['addata']['isbn'].first
    [ENV.fetch('SYNDETICS_PRIMO_URL', nil), '&isbn=', isbn, '/sc.jpg'].join
  end

  def publisher
    return unless @record['pnx']['addata'] && @record['pnx']['addata']['pub']

    @record['pnx']['addata']['pub'].first
  end

  def location
    return unless @record['delivery']
    return unless @record['delivery']['bestlocation']

    loc = @record['delivery']['bestlocation']
    ["#{loc['mainLocation']} #{loc['subLocation']}", loc['callNumber']]
  end

  def subjects
    return [] unless @record['pnx']['display']['subject']

    @record['pnx']['display']['subject']
  end

  def availability
    return unless location

    @record['delivery']['bestlocation']['availabilityStatus']
  end

  def other_availability
    return unless @record['delivery']['bestlocation']
    return unless @record['delivery']['holding']

    @record['delivery']['holding'].length > 1
  end

  # FRBR Group check based on:
  # https://knowledge.exlibrisgroup.com/Primo/Knowledge_Articles/Primo_Search_API_-_how_to_get_FRBR_Group_members_after_a_search
  def frbrized?
    return unless @record['pnx']['facets']
    return unless @record['pnx']['facets']['frbrtype']

    @record['pnx']['facets']['frbrtype'].join == '5'
  end

  def alma_record?
    return false unless identifier

    identifier.start_with?('alma')
  end

  def dedup_url
    return unless frbrized?
    return unless alma_record? # FRBR links do not work for CDI records
    return unless @record['pnx']['facets']['frbrgroupid'] &&
                  @record['pnx']['facets']['frbrgroupid'].length == 1

    frbr_group_id = @record['pnx']['facets']['frbrgroupid'].join
    base = [ENV.fetch('MIT_PRIMO_URL', nil), '/discovery/search?'].join

    query = {
      query: "any,contains,#{@query}",
      tab: ENV.fetch('PRIMO_TAB', nil),
      search_scope: ENV.fetch('PRIMO_SCOPE', nil),
      sortby: 'date_d',
      vid: ENV.fetch('PRIMO_VID', nil),
      facet: "frbrgroupid,include,#{frbr_group_id}"
    }.to_query
    [base, query].join
  end
end
