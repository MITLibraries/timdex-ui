class SearchController < ApplicationController
  before_action :validate_q!, only: %i[results]

  if Flipflop.enabled?(:gdt)
    before_action :validate_geobox_presence!, only: %i[results]
    before_action :validate_geobox_range!, only: %i[results]
    before_action :validate_geobox_values!, only: %i[results]
    before_action :validate_geodistance_presence!, only: %i[results]
    before_action :validate_geodistance_range!, only: %i[results]
    before_action :validate_geodistance_value!, only: %i[results]
    before_action :validate_geodistance_units!, only: %i[results]
  end

  def results
    # inject session preference for boolean type if it is present
    params[:booleanType] = cookies[:boolean_type] || 'AND'

    # Determine which tab to load - default to primo unless gdt is enabled
    @active_tab = if Flipflop.enabled?(:gdt)
                    'gdt' # Keep existing GDT behavior unchanged
                  else
                    params[:tab] || 'primo' # Default to primo for new tabbed interface
                  end
    @enhanced_query = Enhancer.new(params).enhanced_query

    # Route to appropriate search based on active tab
    if Flipflop.enabled?(:gdt)
      # Keep existing GDT behavior unchanged
      load_gdt_results
      render 'results_geo'
    else
      case @active_tab
      when 'primo'
        load_primo_results
      when 'timdex'
        load_timdex_results
      end
    end
  end

  private

  def load_gdt_results
    query = QueryBuilder.new(@enhanced_query).query

    response = query_timdex(query)

    # Handle errors
    @errors = extract_errors(response)
    @pagination = Analyzer.new(@enhanced_query, response).pagination if @errors.nil?
    @results = extract_results(response)
    @filters = extract_filters(response)
  end

  def load_primo_results
    primo_response = query_primo
    @results = NormalizePrimoResults.new(primo_response, @enhanced_query[:q]).normalize

    # Enhanced pagination using cached response
    if @results.present?
      total_hits = primo_response.dig('info', 'total') || @results.count
      per_page = @enhanced_query[:per_page] || 20
      current_page = @enhanced_query[:page] || 1

      @pagination = {
        hits: total_hits,
        start: ((current_page - 1) * per_page) + 1,
        end: [current_page * per_page, total_hits].min
      }
    end
  rescue StandardError => e
    @errors = handle_primo_errors(e)
  end

  def load_timdex_results
    query = QueryBuilder.new(@enhanced_query).query
    response = query_timdex(query)

    @errors = extract_errors(response)
    @pagination = Analyzer.new(@enhanced_query, response).pagination if @errors.nil?
    @results = extract_results(response)
  end

  def active_filters
    ENV.fetch('ACTIVE_FILTERS', '').split(',').map(&:strip)
  end

  def query_timdex(query)
    # We generate unique cache keys to avoid naming collisions.
    cache_key = generate_cache_key(query)

    # Builder hands off to wrapper which returns raw results here.
    Rails.cache.fetch("#{cache_key}/#{@active_tab}", expires_in: 12.hours) do
      raw = if @active_tab == 'gdt'
              execute_geospatial_query(query)
            elsif @active_tab == 'timdex'
              TimdexBase::Client.query(TimdexSearch::BaseQuery, variables: query)
            end

      # The response type is a GraphQL::Client::Response, which is not directly serializable, so we
      # convert it to a hash.
      {
        data: raw.data.to_h,
        errors: raw.errors.details.to_h
      }
    end
  end

  def query_primo
    # We generate unique cache keys to avoid naming collisions.
    cache_key = generate_cache_key(@enhanced_query)

    Rails.cache.fetch("#{cache_key}/primo", expires_in: 12.hours) do
      primo_search = PrimoSearch.new
      per_page = @enhanced_query[:per_page] || 20
      primo_search.search(@enhanced_query[:q], per_page)
    end
  end

  def generate_cache_key(query)
    # Sorting query hash to ensure consistent key generation regardless of the parameter order
    sorted_query = query.sort_by { |k, _v| k.to_sym }.to_h
    Digest::MD5.hexdigest(sorted_query.to_s)
  end

  def execute_geospatial_query(query)
    if query['geobox'] == 'true' && query[:geodistance] == 'true'
      TimdexBase::Client.query(TimdexSearch::AllQuery, variables: query)
    elsif query['geobox'] == 'true'
      TimdexBase::Client.query(TimdexSearch::GeoboxQuery, variables: query)
    elsif query['geodistance'] == 'true'
      TimdexBase::Client.query(TimdexSearch::GeodistanceQuery, variables: query)
    else
      TimdexBase::Client.query(TimdexSearch::BaseQuery, variables: query)
    end
  end

  def extract_errors(response)
    response[:errors]['data'] if response.is_a?(Hash) && response.key?(:errors) && response[:errors].key?('data')
  end

  def extract_filters(response)
    return unless response.is_a?(Hash) && response.key?(:data) && response[:data].key?('search')

    aggs = response[:data]['search']['aggregations']
    return if aggs.blank?

    aggs = reorder_filters(aggs, active_filters) unless active_filters.blank?

    # We use aggregations to determine which terms can be filtered. However, agg names do not include 'filter', whereas
    # our filter fields do (e.g., 'source' vs 'sourceFilter'). Because of this mismatch, we need to modify the
    # aggregation key names before collecting them as filters, so that when a filter is applied, it searches the
    # correct field name.
    aggs
      .select { |_, agg_values| agg_values.present? }
      .transform_keys { |key| (key.dup << 'Filter').to_sym }
  end

  def extract_results(response)
    return unless response.is_a?(Hash) && response.key?(:data) && response[:data].key?('search')

    response[:data]['search']['records']
  end

  def reorder_filters(aggs, active_filters)
    aggs
      .select { |key, _| active_filters.include?(key) }
      .sort_by { |key, _| active_filters.index(key) }.to_h
  end

  def validate_q!
    return if params[:advanced]&.strip.present?
    return if params[:geobox]&.strip.present?
    return if params[:geodistance]&.strip.present?
    return if params[:q]&.strip.present?

    flash[:error] = 'A search term is required.'
    redirect_to root_url
  end

  def validate_geodistance_presence!
    return unless params[:geodistance]&.strip == 'true'

    geodistance_params = [params[:geodistanceLatitude]&.strip, params[:geodistanceLongitude]&.strip,
                          params[:geodistanceDistance]&.strip]
    return if geodistance_params.all?(&:present?)

    flash[:error] = 'All geospatial distance fields are required.'
    redirect_to root_url
  end

  def validate_geobox_presence!
    return unless params[:geobox]&.strip == 'true'

    geobox_params = [params[:geoboxMinLatitude]&.strip, params[:geoboxMinLongitude]&.strip,
                     params[:geoboxMaxLatitude]&.strip, params[:geoboxMaxLongitude]&.strip]
    return if geobox_params.all?(&:present?)

    flash[:error] = 'All bounding box fields are required.'
    redirect_to root_url
  end

  def validate_geodistance_range!
    return unless params[:geodistance]&.strip == 'true'

    invalid_range = false
    lat = params[:geodistanceLatitude]&.strip.to_f
    long = params[:geodistanceLongitude]&.strip.to_f
    invalid_range = true unless lat.between?(-90.0, 90.0)
    invalid_range = true unless long.between?(-180.0, 180.0)

    return if invalid_range == false

    flash[:error] = 'Latitude must be between -90.0 and 90.0, and longitude must be -180.0 and 180.0.'
    redirect_to root_url
  end

  def validate_geobox_range!
    return unless params[:geobox]&.strip == 'true'

    invalid_range = false
    geobox_lat = [params[:geoboxMinLatitude]&.strip.to_f, params[:geoboxMaxLatitude]&.strip.to_f]
    geobox_long = [params[:geoboxMinLongitude]&.strip.to_f, params[:geoboxMaxLongitude]&.strip.to_f]
    invalid_range = true unless geobox_lat.all? { |lat| lat.between?(-90.0, 90.0) }
    invalid_range = true unless geobox_long.all? { |long| long.between?(-180.0, 180.0) }

    return if invalid_range == false

    flash[:error] = 'Latitude must be between -90.0 and 90.0, and longitude must be -180.0 and 180.0.'
    redirect_to root_url
  end

  def validate_geodistance_value!
    return unless params[:geodistance]&.strip == 'true'

    distance = params[:geodistanceDistance]&.strip.to_i
    return if distance.positive?

    flash[:error] = 'Distance must include an integer greater than 0.'
    redirect_to root_url
  end

  def validate_geodistance_units!
    return unless params[:geodistance]&.strip == 'true'

    distance = params[:geodistanceDistance]&.strip
    valid_units = %w[mi miles yd yards ft feet in inch km kilometers m meters cm
                     centimeters mm millimeters NM nmi nauticalmiles]

    # Values with no units are okay. We confirm this by round-tripping the variable to an integer and back, as that
    # conversion strips any non-numeric characters.
    return if distance.to_i.to_s == distance

    # Otherwise, the value should contain one of the acceptable units.
    return if valid_units.any? { |unit| distance.include? unit }

    flash[:error] = 'Distance units must be one of the following: mi, km, yd, ft, in, m, cm, mm, NM/nmi'
    redirect_to root_url
  end

  def validate_geobox_values!
    return unless params[:geobox]&.strip == 'true'

    geobox_lat = [params[:geoboxMinLatitude]&.strip.to_f, params[:geoboxMaxLatitude]&.strip.to_f]

    # Confirm that min latitude value is lower than max value.
    return if geobox_lat[0] < geobox_lat[1]

    flash[:error] = 'Maximum latitude cannot exceed minimum latitude.'
    redirect_to root_url
  end

  def handle_primo_errors(error)
    Rails.logger.error("Primo search error: #{error.message}")

    if error.is_a?(ArgumentError)
      [{ 'message' => 'Primo search is not properly configured.' }]
    elsif error.is_a?(HTTP::TimeoutError)
      [{ 'message' => 'The Primo service is currently slow to respond. Please try again.' }]
    else
      [{ 'message' => error.message }]
    end
  end
end
