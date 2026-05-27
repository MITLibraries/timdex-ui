# Transforms a TIMDEX result into a normalized record.
class NormalizeTimdexRecord
  # Maps raw TIMDEX source names to [display_name, url] pairs.
  # Add new sources here — both fields stay in sync automatically.
  SOURCES = {
    'DSpace@MIT' => ['MIT Open Scholarship (DSpace@MIT)', 'https://dspace.mit.edu/'],
    'LibGuides' => ['Research Guides', 'https://libguides.mit.edu/'],
    'MIT ArchivesSpace' => ['Archives & Manuscripts', 'https://archivesspace.mit.edu'],
    'OpenGeoMetadata GIS Resources' => ['Open Geospatial Consortium', 'https://opengeometadata.org/'],
    'MIT GIS Resources' => ['MIT Geospatial Data', 'https://geodata.libraries.mit.edu/'],
    'Research Databases' => ['Research Databases', 'https://libguides.mit.edu/az/databases'],
    'MIT Libraries Website' => ['Library Website', 'https://libraries.mit.edu/'],
    'MIT Alma' => ['MIT Libraries Catalog',
                   "#{ENV.fetch('MIT_PRIMO_URL')}/discovery/search?vid=#{ENV.fetch('PRIMO_VID')}&lang=en"]
  }.freeze

  def initialize(record, query)
    @record = record
    @query = query
  end

  def normalize
    {
      # Core fields
      api: 'timdex',
      title:,
      creators:,
      eyebrow:,
      source:,
      source_url:,
      year:,
      format:,
      links:,
      citation:,
      identifier:,
      summary:,
      publisher:,
      location:,
      subjects:,
      # TIMDEX-specific fields
      content_type:,
      date_range:,
      dates:,
      contributors:,
      highlight:,
      source_link:
    }
  end

  private

  def title
    title = @record['title'] || 'Unknown title'

    # The collection identifier is important for ASpace records so we append it to the title
    return title unless @record['source'] == 'MIT ArchivesSpace'

    title += " (#{aspace_collection(@record['identifiers'])})"
  end

  def aspace_collection(identifiers)
    relevant_ids = identifiers.map { |id| id['value'] if id['kind'] == 'Collection Identifier' }.compact

    # In the highly unlikely event that there is more than one collection identifier, there's something weird going
    # on with the record and we should look into it.
    if relevant_ids.count > 1
      Sentry.set_tags('mitlib.recordId': identifier || 'empty record id')
      Sentry.set_tags('mitlib.collection_ids': relevant_ids.join('; '))
      Sentry.capture_message('Multiple Collection IDs found in ASpace record')
    end

    relevant_ids.first
  end

  def creators
    return [] unless @record['contributors']

    # Convert TIMDEX contributors to Primo-style creators format
    @record['contributors']
      .select { |c| %w[Creator Author].include?(c['kind']) }
      .map { |creator| { 'value' => creator['value'], 'link' => nil } }
  end

  def eyebrow
    format
  end

  # Maps sources to user friendly display names
  def source
    return 'Unknown source' unless @record['source']

    SOURCES.fetch(@record['source'], [@record['source']]).first
  end

  # Returns the URL for the source system, or nil if not mapped
  def source_url
    SOURCES[@record['source']]&.last
  end

  def year
    # Extract year from dates
    return nil unless @record['dates']

    pub_date = @record['dates'].find { |date| date['kind'] == 'Publication date' }
    return pub_date['value']&.match(/\d{4}/)&.to_s if pub_date

    # Fallback to any date with a year
    @record['dates'].each do |date|
      year_match = date['value']&.match(/\d{4}/)
      return year_match.to_s if year_match
    end
  end

  # This is used in eyebrows and is similar to content_type but returns a default string if contentType is missing.
  # This difference allows us to always have an eyebrow.
  def format
    return 'Unknown format' unless @record['contentType']

    @record['contentType']&.map { |term| Vocabularies::Format.lookup(term) }&.join(' ; ')
  end

  def links
    links = []

    # Add source link if available
    if @record['sourceLink']
      links << {
        'kind' => 'full record',
        'url' => @record['sourceLink'],
        'text' => 'View full record'
      }
    end

    links
  end

  def citation
    @record['citation']
  end

  def summary
    return nil unless @record['summary']

    @record['summary'].is_a?(Array) ? @record['summary'].join(' ') : @record['summary']
  end

  def publisher
    # Extract from contributors or other fields
    return nil unless @record['contributors']

    publisher = @record['contributors'].find { |c| c['kind'] == 'Publisher' }
    publisher&.dig('value')
  end

  def location
    return nil unless @record['locations']

    @record['locations'].map { |loc| loc['value'] }.compact.join('; ')
  end

  def subjects
    return [] unless @record['subjects']

    @record['subjects'].flat_map { |subject| subject['value'] }
  end

  def identifier
    @record['timdexRecordId']
  end

  # TIMDEX-specific methods

  # This is similar to the format field above, but does not return a default string if contentType is missing.
  def content_type
    @record['contentType']&.map { |term| Vocabularies::Format.lookup(term) }&.join(' ; ')
  end

  def dates
    @record['dates']
  end

  def date_range
    return unless @record['dates']

    # Some records have creation or publication dates that are ranges. Extract those here.
    relevant_dates = @record['dates'].select do |date|
      %w[creation publication].include?(date['kind']) && date['range'].present?
    end

    # If the record has no creation or publication date, stop here.
    return if relevant_dates.empty?

    # If the record *does* have more than one creation/pub date, just take the first one. Note: ASpace records often
    # have more than one. Sometimes they are duplicates, sometimes they are different. For now we will just take the
    # first.
    relevant_date = relevant_dates.first

    "#{relevant_date['range']['gte']} to #{relevant_date['range']['lte']}"
  end

  def contributors
    @record['contributors']
  end

  def highlight
    @record['highlight']
  end

  def source_link
    @record['sourceLink']
  end
end
