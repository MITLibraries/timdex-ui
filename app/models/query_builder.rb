class QueryBuilder
  attr_reader :query

  QUERY_PARAMS = %w[q citation contributors fundingInformation identifiers locations subjects title booleanType].freeze
  FILTER_PARAMS = %i[accessToFilesFilter contentTypeFilter contributorsFilter formatFilter languagesFilter
                     literaryFormFilter placesFilter sourceFilter subjectsFilter].freeze
  GEO_PARAMS = %w[geoboxMinLongitude geoboxMinLatitude geoboxMaxLongitude geoboxMaxLatitude geodistanceLatitude
                  geodistanceLongitude geodistanceDistance].freeze
  VALID_QUERY_MODES = %w[keyword semantic hybrid].freeze

  def initialize(enhanced_query)
    @query = {}
    @per_page = ENV.fetch('RESULTS_PER_PAGE', '20').to_i
    @query['from'] = calculate_from(enhanced_query[:page], @per_page)

    if Feature.enabled?(:geodata)
      @query['geobox'] = 'true' if enhanced_query[:geobox] == 'true'
      @query['geodistance'] = 'true' if enhanced_query[:geodistance] == 'true'
    end

    extract_query(enhanced_query)
    extract_geosearch(enhanced_query)
    extract_filters(enhanced_query)
    evaluate_query_mode(enhanced_query)
    @query['index'] = ENV.fetch('TIMDEX_INDEX', nil)
    @query['booleanType'] = enhanced_query[:booleanType]
    @query.compact!
  end

  private

  def calculate_from(page = 1, per_page = ENV.fetch('RESULTS_PER_PAGE', '20').to_i)
    # This needs to return a string because Timdex needs $from to be a String
    page = 1 if page.to_i.zero?
    ((page - 1) * per_page).to_s
  end

  def extract_query(enhanced_query)
    QUERY_PARAMS.each do |qp|
      @query[qp] = enhanced_query[qp.to_sym]&.strip
    end
  end

  def extract_geosearch(enhanced_query)
    return unless Feature.enabled?(:geodata)

    GEO_PARAMS.each do |gp|
      if coerce_to_float?(gp)
        @query[gp] = enhanced_query[gp.to_sym]&.strip.to_f unless enhanced_query[gp.to_sym].blank?
      else
        @query[gp] = enhanced_query[gp.to_sym]&.strip
      end
    end
  end

  def extract_filters(enhanced_query)
    FILTER_PARAMS.each do |qp|
      @query[qp] = enhanced_query[qp]
    end
  end

  # The GraphQL API requires that lat/long in geospatial fields be floats
  def coerce_to_float?(geo_param)
    geo_param.to_s.include?('Longitude') || geo_param.to_s.include?('Latitude')
  end

  # Determine the query mode from URL parameter or config, with fallback to 'keyword'
  # Only allows valid modes: keyword, semantic, hybrid
  def evaluate_query_mode(enhanced_query)
    mode = enhanced_query[:queryMode] || ENV.fetch('DEFAULT_QUERY_MODE', 'keyword')
    mode = mode.to_s.downcase.strip

    # Validate against allow list
    mode = 'keyword' unless VALID_QUERY_MODES.include?(mode)

    # Override mode based on numeric tuning parameter if specific values present
    if enhanced_query[:queryTuning]
      Rails.logger.debug 'Query Tuning parameter present - checking for override'
      Rails.logger.debug "queryTuning is #{enhanced_query[:queryTuning]}"
      mode = 'keyword' if enhanced_query[:queryTuning].to_f == 0.0
      mode = 'hybrid' if (enhanced_query[:queryTuning].to_f - 0.5).abs < Float::EPSILON
      mode = 'semantic' if (enhanced_query[:queryTuning].to_f - 1.0).abs < Float::EPSILON
      Rails.logger.debug "Query mode set to #{mode}"
    end

    @query['queryMode'] = mode
  end
end
