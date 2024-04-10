class Enhancer
  include QueryElements

  attr_accessor :enhanced_query

  # Accepts all params as each enhancer may require different data.
  #
  # Note that we are using `Rack::Utils` to parse the query params rather than just invoking `params`. This is because
  # `to_params`, `to_query`, and seemingly all other Rails URL helpers [sort params lexicographically](https://github.com/rails/rails/blob/main/activesupport/lib/active_support/core_ext/object/to_query.rb#L73-L74).
  # In order to retain the order in which a user applies filters, we need either to avoid these helpers or cache the
  # filter application order. This approach seems less complex, and it supports user agents that are blocking cookies.
  def initialize(url)
    @enhanced_query = {}
    query_params = Rack::Utils.parse_nested_query(URI(url).query)

    @enhanced_query[:page] = calculate_page(query_params['page'].to_i)
    @enhanced_query[:advanced] = 'true' if query_params['advanced'].present?

    if Flipflop.enabled?(:gdt)
      @enhanced_query[:geobox] = 'true' if query_params['geobox'] == 'true'
      @enhanced_query[:geodistance] = 'true' if query_params['geodistance'] == 'true'
    end

    extract_query(query_params)
    extract_geosearch(query_params)
    extract_filters(query_params)
    patterns(query_params) if query_params['q']
  end

  private

  def calculate_page(value = 0)
    value < 1 ? 1 : value
  end

  def extract_query(params)
    params.each do |param_key, param_value|
      next unless QueryElements::QUERY_PARAMS.include? param_key.to_sym

      next if param_value.blank?

      @enhanced_query[param_key.to_sym] = param_value
    end
  end

  def extract_geosearch(params)
    return unless Flipflop.enabled?(:gdt)

    params.each do |param_key, param_value|
      next unless QueryElements::GEO_PARAMS.include? param_key.to_sym

      next if param_value.blank?

      @enhanced_query[param_key.to_sym] = param_value
    end
  end

  def extract_filters(params)
    params.each do |param_key, param_value|
      next unless QueryElements::FILTER_PARAMS.include? param_key.to_sym

      next if param_value.blank?

      @enhanced_query[param_key.to_sym] = param_value
    end
  end

  def patterns(params)
    @enhanced_query = EnhancerPatterns.new(@enhanced_query, params['q']).enhanced_query
  end
end
