class QueryBuilder
  attr_reader :query

  RESULTS_PER_PAGE = 20
  QUERY_PARAMS = %w[q citation contributors fundingInformation identifiers locations subjects title booleanType].freeze
  FILTER_PARAMS = %i[accessToFilesFilter contentTypeFilter contributorsFilter formatFilter languagesFilter
                     literaryFormFilter placesFilter sourceFilter subjectsFilter].freeze
  GEO_PARAMS = %w[geoboxMinLongitude geoboxMinLatitude geoboxMaxLongitude geoboxMaxLatitude geodistanceLatitude
                  geodistanceLongitude geodistanceDistance].freeze

  def initialize(enhanced_query)
    @query = {}
    @query['from'] = calculate_from(enhanced_query[:page])

    if Feature.enabled?(:geodata)
      @query['geobox'] = 'true' if enhanced_query[:geobox] == 'true'
      @query['geodistance'] = 'true' if enhanced_query[:geodistance] == 'true'
    end

    extract_query(enhanced_query)
    extract_geosearch(enhanced_query)
    extract_filters(enhanced_query)
    @query['index'] = ENV.fetch('TIMDEX_INDEX', nil)
    @query['booleanType'] = enhanced_query[:booleanType]
    @query.compact!
  end

  private

  def calculate_from(page = 1)
    # This needs to return a string because Timdex needs $from to be a String
    page = 1 if page.to_i.zero?
    ((page - 1) * RESULTS_PER_PAGE).to_s
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
end
