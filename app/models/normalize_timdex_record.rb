# Transforms a TIMDEX result into a normalized record.
class NormalizeTimdexRecord
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
      'subjects' => subjects,
      # TIMDEX-specific fields
      'content_type' => content_type,
      'dates' => dates,
      contributors:,
      'highlight' => highlight,
      'source_link' => source_link
    }
  end

  private

  def title
    @record['title'] || 'Unknown title'
  end

  def creators
    return [] unless @record['contributors']

    # Convert TIMDEX contributors to Primo-style creators format
    @record['contributors']
      .select { |c| %w[Creator Author].include?(c['kind']) }
      .map { |creator| { 'value' => creator['value'], 'link' => nil } }
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

    @record['subjects'].map { |subject| subject['value'] }
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
