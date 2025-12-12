# Transforms a TIMDEX result into a normalized record.
class NormalizeTimdexRecord
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
    return title unless source == 'MIT ArchivesSpace'

    title += " (#{aspace_collection(@record['identifiers'])})"
  end

  def aspace_collection(identifiers)
    relevant_ids = identifiers.map { |id| id['value'] if id['kind'] == 'Collection Identifier' }.compact

    # In the highly unlikely event that there is more than one collection identifier, there's something weird going
    # on with the record and we should skip it.
    return if relevant_ids.count > 1

    relevant_ids.first
  end

  def creators
    return [] unless @record['contributors']

    # Convert TIMDEX contributors to Primo-style creators format
    @record['contributors']
      .select { |c| %w[Creator Author].include?(c['kind']) }
      .map { |creator| { 'value' => creator['value'], 'link' => nil } }
  end

  # Maps sources to user friendly strings
  def eyebrow
    case source
    when 'DSpace@MIT'
      'DSpace@MIT (MIT Research)'
    when 'LibGuides'
      'MIT Libraries Website: Guides'
    when 'OpenGeoMetadata GIS Resources'
      'Non-MIT GeoSpatial Data'
    when 'MIT GIS Resources'
      'MIT GeoSpatial Data'
    else
      source
    end
  end

  def source
    return 'Unknown source' unless @record['source']

    @record['source']
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

  def format
    return '' unless @record['contentType']

    @record['contentType'].map { |type| type['value'] }.join(' ; ')
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
    @record['citation'] || nil
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
  def content_type
    @record['contentType']
  end

  def dates
    @record['dates']
  end

  def date_range
    return unless @record['dates']

    # Some records have creation or publication dates that are ranges. Extract those here.
    relevant_dates = @record['dates'].select { |date| %w[creation publication].include?(date['kind']) }

    # If the record has no creation or publication date, stop here.
    return if relevant_dates.empty?

    # If the record *does* have more than one creation/pub date, just take the first one. Note: ASpace records often
    # have more than one. Sometimes they are duplicates, sometimes they are different. For now we will just take the
    # first.
    relevant_date = relevant_dates.first

    # We are only concerned with creation/pub dates that are ranges.
    return unless relevant_date['range'].present?

    "#{relevant_date['range']['gte']}-#{relevant_date['range']['lte']}"
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
