# Transforms a Primo Search API result into a normalized record.
class NormalizePrimoRecord
  def initialize(record, query)
    @record = record
    @query = query
  end

  def normalize
    {
      # Core fields
      api: 'primo',
      title:,
      creators:,
      eyebrow:,
      source:,
      year:,
      format:,
      links:,
      citation:,
      identifier:,
      doi:,
      pmid:,
      issn:,
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
      other_availability:,
      frbrized: frbrized?
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

  # Provides user friendly string based on whether the record is Alma or not-Alma (CDI)
  def eyebrow
    if alma_record?
      'MIT Libraries Catalog'
    else
      'MIT Libraries Catalog: Articles'
    end
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

    @record['pnx']['display']['type'].map { |term| Vocabularies::Format.lookup(term) }&.join(' ; ')
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

    # Add PDF if available
    if @record['pnx']['links'] && @record['pnx']['links']['linktopdf']

      parsed_string = parse_link_string(@record['pnx']['links']['linktopdf'].first)

      if parsed_string['U'].present?
        links << { 'url' => parsed_string['U'],
                   'kind' => 'Get PDF' }
      end
    end

    # Add HTML if available
    if @record['pnx']['links'] && @record['pnx']['links']['linktohtml']

      parsed_string = parse_link_string(@record['pnx']['links']['linktohtml'].first)

      if parsed_string['U'].present?
        links << { 'url' => parsed_string['U'],
                   'kind' => 'Read online' }
      end
    end

    # Return links if we found any
    links.any? ? links : []
  end

  # Parses a link string into a hash of key-value pairs.
  # The link string is a series of key-value pairs separated by $$, where each pair is prefixed by a single character.
  # For example: "$$Uhttps://example.com$$TView PDF" would be parsed into { 'U' => 'https://example.com', 'T' => 'View PDF' }
  def parse_link_string(link_string)
    return unless link_string.start_with?('$$')

    parts = link_string.split('$$')
    hash = {}
    parts.each do |part|
      next if part.empty?

      key = part[0]
      value = part[1..-1]
      hash[key] = value
    end
    hash
  end

  def citation
    # We don't want to include citations for Alma records at this time. If we include them in the future they need
    # to be cleaned up as they currently look like `Engineering village 2$$QEngineering village 2`
    return if alma_record?
    return unless @record['pnx']['display']

    @record['pnx']['display']['ispartof']&.first
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

  def doi
    return unless @record['pnx']['addata'] && @record['pnx']['addata']['doi']

    if @record['pnx']['addata']['doi'].length > 1
      Sentry.set_tags('mitlib.recordId': identifier || 'empty record id')
      Sentry.capture_message('Multiple DOIs found in one record')
    end

    @record['pnx']['addata']['doi'].first
  end

  def pmid
    return unless @record['pnx']['addata'] && @record['pnx']['addata']['pmid']

    if @record['pnx']['addata']['pmid'].length > 1
      Sentry.set_tags('mitlib.recordId': identifier || 'empty record id')
      Sentry.capture_message('Multiple PMIDs found in one record')
    end

    @record['pnx']['addata']['pmid'].first
  end

  def issn
    return unless @record['pnx']['addata'] && @record['pnx']['addata']['issn']

    # Unlike DOI and PMID, it's common for a record to have multiple ISSNs (e.g., print and electronic).
    # Therefore, we don't log an error if there are multiple ISSNs.
    @record['pnx']['addata']['issn'].first
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

  # Current logic in this method should likely move to `holdings` field
  def location
    return unless @record['delivery']
    return unless @record['delivery']['bestlocation']

    loc = @record['delivery']['bestlocation']

    {
      name: loc['mainLocation'],
      collection: loc['subLocation'],
      call_number: loc['callNumber']
    }
  end

  def subjects
    return [] unless @record['pnx']['display']['subject']

    subs = @record['pnx']['display']['subject']
    subs.flat_map { |sub| sub.split(' ;  ') }
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
