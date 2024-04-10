class QueryBuilder
  include QueryElements

  attr_reader :query

  def initialize(enhanced_query)
    @query = {}
    @query['from'] = calculate_from(enhanced_query[:page])

    if Flipflop.enabled?(:gdt)
      @query['geobox'] = 'true' if enhanced_query[:geobox] == 'true'
      @query['geodistance'] = 'true' if enhanced_query[:geodistance] == 'true'
    end

    extract_query(enhanced_query)
    extract_geosearch(enhanced_query)
    extract_filters(enhanced_query)
    @query['index'] = ENV.fetch('TIMDEX_INDEX', nil)
    @query.compact!
  end

  private

  def calculate_from(page = 1)
    # This needs to return a string because Timdex needs $from to be a String
    page = 1 if page.to_i.zero?
    ((page - 1) * QueryElements::RESULTS_PER_PAGE).to_s
  end

  def extract_query(enhanced_query)
    enhanced_query.each do |query_key, query_value|
      next unless QueryElements::QUERY_PARAMS.include? query_key

      @query[query_key.to_s] = stripped_value(query_value)
    end
  end

  def extract_geosearch(enhanced_query)
    return unless Flipflop.enabled?(:gdt)

    enhanced_query.each do |query_key, query_value|
      next unless QueryElements::GEO_PARAMS.include? query_key

      if coerce_to_float?(query_key)
        @query[query_key.to_s] = query_value.to_f unless query_value.blank?
      else
        @query[query_key.to_s] = stripped_value(query_value)
      end
    end
  end

  def extract_filters(enhanced_query)
    enhanced_query.each do |query_key, query_value|
      next unless QueryElements::FILTER_PARAMS.include? query_key

      @query[query_key.to_s] = stripped_value(query_value)
    end
  end

  # The GraphQL API requires that lat/long in geospatial fields be floats
  def coerce_to_float?(geo_param)
    geo_param.to_s.include?('Longitude') || geo_param.to_s.include?('Latitude')
  end

  def stripped_value(value)
    value.is_a?(Array) ? value.map(&:strip) : value.strip
  end
end
