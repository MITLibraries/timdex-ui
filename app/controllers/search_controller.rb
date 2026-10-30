class SearchController < ApplicationController
  # Increment this namespace when the normalized search result payload changes in a way that
  # makes existing cached values incomplete or incompatible, such as adding required fields,
  # removing/renaming fields, changing key types, or changing error/continuation metadata shape.
  SEARCH_RESULTS_CACHE_NAMESPACE = 'normalized-search-results/v2'.freeze
  SEARCH_RESULTS_CACHE_TTL = 12.hours

  before_action :validate_q!, only: %i[results]
  before_action :authorized_request?, only: %i[results]
  before_action :set_active_tab, only: %i[results]
  around_action :sleep_if_too_fast, only: %i[results]

  before_action :validate_geobox_presence!, only: %i[results]
  before_action :validate_geobox_range!, only: %i[results]
  before_action :validate_geobox_values!, only: %i[results]
  before_action :validate_geodistance_presence!, only: %i[results]
  before_action :validate_geodistance_range!, only: %i[results]
  before_action :validate_geodistance_value!, only: %i[results]
  before_action :validate_geodistance_units!, only: %i[results]

  def results
    @primo_result_count = 0
    @timdex_result_count = 0

    # inject session preference for boolean type if it is present
    params[:booleanType] = cookies[:boolean_type] || 'AND'

    # inject hybrid queryMode if opted-in and no queryMode param provided
    params[:queryMode] = 'hybrid' if params[:queryMode].blank? && nls_enabled_value == 'true'

    @enhanced_query = Enhancer.new(params).enhanced_query
    @show_nls_warning = show_nls_warning?
    @pagination_load_more_enabled = pagination_load_more_enabled?

    # Load GeoData results if applicable
    if Feature.enabled?(:geodata)
      load_geodata_results
      respond_to do |format|
        format.turbo_stream { render :results_geo }
        format.html { render 'results_geo' }
      end
      return
    end

    # Route to appropriate search based on active tab
    case @active_tab
    when 'all'
      load_all_results
    when *primo_tabs
      load_primo_results
    when *timdex_tabs
      load_timdex_results
    end

    # Render the response in HTML or JSON format
    respond_to do |format|
      format.json { render json: { results: @results, hits: hit_count, errors: @errors } }
      format.turbo_stream { render :results }
      format.html { render :results }
    end
  end

  private

  # This returns the total result count from whichever instance variable is present
  def hit_count
    if @pagination_load_more_enabled
      @load_more&.[](:total_hits) || 0
    else
      @pagination&.[](:hits) || 0
    end
  end

  # Sleep to simulate latency for testing loading indicators when responses are fast
  def sleep_if_too_fast
    start_time = Time.now

    yield

    end_time = Time.now
    duration = end_time - start_time

    return unless Feature.enabled?(:simulate_search_latency)

    Rails.logger.debug "Action #{action_name} from controller #{controller_name} took #{duration.round(2)} seconds to execute."

    return unless duration < 1

    Rails.logger.debug("Sleeping for #{1 - duration}")
    sleep(1 - duration)
  end

  def load_geodata_results
    query = QueryBuilder.new(@enhanced_query).query
    cached = cached_timdex_data(query, include_filters: true)

    @errors = cached[:errors]
    return unless @errors.nil?

    @timdex_result_count = cached[:hits]
    @pagination = Analyzer.new(@enhanced_query, cached[:hits], :timdex).pagination
    @results = cached[:results]
    @filters = cached[:filters]
    return unless @pagination_load_more_enabled

    @append_results = @results
    @load_more = load_more_from_pagination(@pagination)
  end

  def load_primo_results
    options = @pagination_load_more_enabled && !request.format.json? ? source_load_more_options : {}
    data = full_page_load_more_reload? ? fetch_primo_data_through_current_page : fetch_primo_data(**options)
    @results = data[:results]
    @pagination = data[:pagination]
    @errors = data[:errors]
    @show_primo_continuation = data[:show_continuation]
    @primo_result_count = data[:hits].to_i
    return unless @pagination_load_more_enabled

    @append_results = @results
    @load_more = load_more_from_pagination(@pagination)
  end

  def load_timdex_results
    options = @pagination_load_more_enabled && !request.format.json? ? source_load_more_options : {}
    data = full_page_load_more_reload? ? fetch_timdex_data_through_current_page : fetch_timdex_data(**options)
    @results = data[:results]
    @pagination = data[:pagination]
    @errors = data[:errors]
    @timdex_result_count = data[:hits].to_i
    return unless @pagination_load_more_enabled

    @append_results = @results
    @load_more = load_more_from_pagination(@pagination)
  end

  # Source-specific tabs fetch only a single page/offset of results per request; the load-more UI
  # relies on Turbo Stream requests to append each new batch onto results already present in the DOM.
  # If a load-more continuation URL (`page` > 1) is ever rendered as a full HTML document instead -
  # e.g. after a bot-detection redirect to Turnstile bounces the user back mid-load-more - there is no
  # existing DOM to append to, so only that single page would be shown instead of everything loaded
  # so far. Detect that case so we can reconstruct the complete cumulative result list instead.
  def full_page_load_more_reload?
    return false unless @pagination_load_more_enabled
    return false unless request.format == Mime[:html]

    (@enhanced_query[:page] || 1).to_i > 1
  end

  # Reconstructs the full cumulative Primo result list for a load-more continuation page rendered as a
  # full HTML document, by re-fetching (and concatenating) every earlier page. Earlier pages are
  # cheap to re-fetch since they're already cache-backed by `cached_primo_data`.
  def fetch_primo_data_through_current_page
    per_page = ENV.fetch('RESULTS_PER_PAGE', '20').to_i
    combined_results = []
    last_data = nil
    last_result_page = 1
    last_result_hits = nil

    (1..bounded_source_page).each do |page|
      last_data = fetch_primo_data(offset: (page - 1) * per_page, per_page: source_page_size(page))
      combined_results.concat(last_data[:results])
      if last_data[:results].any?
        last_result_page = page
        last_result_hits = last_data[:hits]
      end
      break if last_data[:errors].present? || last_data[:show_continuation]
      break if last_data[:results].empty? || page * per_page >= last_data[:hits].to_i
    end

    return last_data.merge(results: combined_results) if last_data[:errors].present?

    hits = last_result_hits || last_data[:hits]
    pagination = Analyzer.new(@enhanced_query.merge(page: last_result_page), hits, :primo,
                              nil, per_page).pagination
    pagination[:end] = combined_results.length
    if last_data[:show_continuation] || last_data[:results].empty? || combined_results.length >= max_load_count
      pagination[:next] = nil
    end
    last_data.merge(results: combined_results, pagination: pagination, hits: hits)
  end

  # Reconstructs the full cumulative TIMDEX result list for a load-more continuation page rendered as
  # a full HTML document. See `fetch_primo_data_through_current_page` for why this is necessary.
  def fetch_timdex_data_through_current_page
    per_page = ENV.fetch('RESULTS_PER_PAGE', '20').to_i
    combined_results = []
    last_data = nil
    last_result_page = 1

    (1..bounded_source_page).each do |page|
      last_data = fetch_timdex_data(offset: (page - 1) * per_page, per_page: source_page_size(page))
      combined_results.concat(last_data[:results])
      last_result_page = page if last_data[:results].any?
      break if last_data[:errors].present? || last_data[:results].empty? || page * per_page >= last_data[:hits].to_i
    end

    return last_data.merge(results: combined_results) if last_data[:errors].present?

    # A stale continuation URL may be beyond the final page. Describe the
    # results we actually reconstructed, and stop navigation after an empty page.
    pagination = Analyzer.new(@enhanced_query.merge(page: last_result_page), last_data[:hits], :timdex,
                              nil, per_page).pagination
    pagination[:end] = combined_results.length
    pagination[:next] = nil if last_data[:results].empty? || combined_results.length >= max_load_count
    last_data.merge(results: combined_results, pagination: pagination)
  end

  def load_all_results
    # Inject wrapper fetchers so the service can call back into this controller's
    # instance methods while preserving request-scoped context and caching behavior.
    merge_service = MergedSearchService.new(
      enhanced_query: @enhanced_query,
      active_tab: @active_tab,
      primo_fetcher: ->(offset:, per_page:, query: nil) { fetch_primo_data(offset: offset, per_page: per_page) },
      timdex_fetcher: ->(offset:, per_page:, query: nil) { fetch_timdex_data(offset: offset, per_page: per_page) }
    )
    if @pagination_load_more_enabled
      display_count = sanitized_load_count
      stable_count = previous_load_count(display_count)
      data = merge_service.fetch(display_count: display_count, stable_count: stable_count)
      collect_frbr_group_ids(data[:frbr_group_ids])

      @results = data[:results]
      @append_results = data[:append_results]
      @errors = data[:errors]
      @load_more = data[:load_more]
      @primo_result_count = data[:primo_hits].to_i
      @timdex_result_count = data[:timdex_hits].to_i
      return
    end

    current_page = @enhanced_query[:page] || 1
    per_page = ENV.fetch('RESULTS_PER_PAGE', '20').to_i
    data = merge_service.fetch(page: current_page, per_page: per_page)

    @results = data[:results]
    @errors = data[:errors]
    @pagination = data[:pagination]
    @show_primo_continuation = data[:show_primo_continuation]
    @primo_result_count = data[:primo_hits].to_i
    @timdex_result_count = data[:timdex_hits].to_i
  end

  # Adds SearchController result fields to Rails' existing request log payload.
  # App-wide log fields are added by ApplicationController.
  def append_info_to_payload(payload)
    super
    payload.merge!(search_results_log_payload) if search_results_log_payload_available?
  end

  # Result-specific log fields are only available after the results action has
  # built its enhanced query.
  def search_results_log_payload_available?
    action_name == 'results' && instance_variable_defined?(:@enhanced_query)
  end

  # Builds the results-only search fields for the request log payload. These
  # values depend on the results action having parsed the query and loaded data
  # from Primo, TIMDEX, or both.
  def search_results_log_payload
    payload = {
      search_tab: search_results_log_search_tab,
      primo_result_count: @primo_result_count.to_i,
      timdex_result_count: @timdex_result_count.to_i,
      searchterm: @enhanced_query[:q].to_s,
      query_mode: search_results_log_query_mode
    }

    frbr_group_ids = @frbr_group_ids&.uniq&.sort
    payload[:frbr_group_ids] = frbr_group_ids if frbr_group_ids.present?
    payload
  end

  # Normalizes the active tab for search result logging. GeoData bypasses the
  # normal tab system, so it gets an explicit synthetic tab value.
  def search_results_log_search_tab
    return 'geodata' if Feature.enabled?(:geodata)

    @active_tab.presence || @enhanced_query[:tab].presence || 'all'
  end

  # Normalizes query mode for search result logging, matching QueryBuilder's
  # accepted values and fallback behavior so logs reflect the executed search.
  def search_results_log_query_mode
    mode = @enhanced_query[:queryMode].presence || ENV.fetch('DEFAULT_QUERY_MODE', 'keyword')
    mode = mode.to_s.downcase.strip
    return mode if QueryBuilder::VALID_QUERY_MODES.include?(mode)

    'keyword'
  end

  # Builds the shared load-more view model for source-specific tabs that still
  # use traditional page/offset mechanics internally. The UI presents one
  # growing list, while the next request simply fetches the next existing page.
  def load_more_from_pagination(pagination)
    return nil if pagination.blank?

    next_page = pagination[:next]
    display_count = pagination[:end]
    unless Feature.enabled?(:geodata)
      display_count = [display_count, max_load_count].min
      next_page = nil if next_page && (next_page - 1) * load_more_batch_size >= max_load_count
    end

    {
      display_count: display_count,
      next_page: next_page,
      has_more: next_page.present?,
      total_hits: pagination[:hits]
    }
  end

  # Returns the visible all-tab result count requested by the browser. This is
  # intentionally separate from `page`: source-specific tabs keep using page for
  # API offsets, while the all tab uses a display count to grow a stable reranked
  # result list.
  def sanitized_load_count
    requested = params[:load_count].to_i
    requested = load_more_batch_size if requested < 1
    [requested, max_load_count].min
  end

  def load_more_batch_size
    ENV.fetch('RESULTS_PER_PAGE', '20').to_i
  end

  # Bound both the reconstruction work and the records returned by the last batch.
  def bounded_source_page
    max_page = (max_load_count.to_f / load_more_batch_size).ceil
    (@enhanced_query[:page] || 1).to_i.clamp(1, max_page)
  end

  def source_page_size(page)
    [load_more_batch_size, max_load_count - (page - 1) * load_more_batch_size].min
  end

  def source_load_more_options
    @enhanced_query[:page] = bounded_source_page
    { offset: (@enhanced_query[:page] - 1) * load_more_batch_size,
      per_page: source_page_size(@enhanced_query[:page]) }
  end

  # Continuation links carry the actual previous count because the final batch
  # may be smaller than RESULTS_PER_PAGE when capped by LOAD_MORE_MAX_RESULTS.
  def previous_load_count(display_count)
    previous = params[:load_previous_count]
    previous = display_count - load_more_batch_size if previous.nil?
    previous.to_i.clamp(0, display_count)
  end

  def max_load_count
    ENV.fetch('LOAD_MORE_MAX_RESULTS', '200').to_i
  end

  def pagination_load_more_enabled?
    Feature.enabled?(:pagination_load_more)
  end

  def fetch_primo_data(offset: nil, per_page: nil)
    # Default to current page if not provided
    current_page = @enhanced_query[:page] || 1
    per_page ||= ENV.fetch('RESULTS_PER_PAGE', '20').to_i
    offset ||= (current_page - 1) * per_page

    # Check if we're beyond Primo API limits before making the request.
    if offset >= Analyzer::PRIMO_MAX_OFFSET
      return { results: [], pagination: {}, errors: nil, show_continuation: true, hits: 0 }
    end

    cached = cached_primo_data(per_page, offset)
    collect_frbr_group_ids(cached[:frbr_group_ids])
    pagination = Analyzer.new(@enhanced_query, cached[:hits], :primo).pagination

    cached.merge(pagination: pagination)
  rescue StandardError => e
    { results: [], pagination: {}, errors: handle_primo_errors(e), show_continuation: false, hits: 0 }
  end

  def fetch_timdex_data(offset: nil, per_page: nil)
    query = QueryBuilder.new(@enhanced_query).query
    query['from'] = offset.to_s if offset
    query['perPage'] = per_page || ENV.fetch('RESULTS_PER_PAGE', '20').to_i
    query['fulltext'] = true if Feature.enabled?(:timdex_fulltext)

    cached = cached_timdex_data(query)
    return cached.merge(pagination: {}) if cached[:errors]

    pagination = Analyzer.new(@enhanced_query, cached[:hits], :timdex).pagination
    cached.merge(pagination: pagination)
  end

  def cached_primo_data(per_page, offset)
    cache_key = CacheKeyGenerator.call(
      @enhanced_query.except(:page).merge(tab: @active_tab, per_page: per_page, offset: offset)
    )

    Rails.cache.fetch("#{SEARCH_RESULTS_CACHE_NAMESPACE}/#{cache_key}/primo", expires_in: SEARCH_RESULTS_CACHE_TTL) do
      primo_response = query_primo(per_page, offset)
      hits = primo_response.dig('info', 'total') || 0
      normalizer = NormalizePrimoResults.new(primo_response, @enhanced_query[:q])
      results = normalizer.normalize

      build_primo_cache_payload(primo_response, results, hits, offset).merge(frbr_group_ids: normalizer.frbr_group_ids)
    end
  end

  def build_primo_cache_payload(primo_response, results, hits, offset)
    # Handle empty results from Primo API. Sometimes Primo will return no results at a given offset,
    # despite claiming in the initial query that more are available. This happens randomly and
    # seemingly for no reason (well below the recommended offset of 2,000). While the bug also
    # exists in Primo UI, sending users there seems like the best we can do.
    show_continuation = false
    errors = nil

    if results.empty?
      docs = primo_response['docs'] if primo_response.is_a?(Hash)
      if docs.nil? || docs.empty?
        # Only show continuation for pagination scenarios (where offset is present), not for
        # searches with no results
        show_continuation = true if offset > 0
      else
        errors = [{ 'message' => 'No more results available at this page number.' }]
      end
    end

    { results: results, errors: errors, show_continuation: show_continuation, hits: hits }
  end

  def cached_timdex_data(query, include_filters: false)
    prepare_timdex_query(query)
    cache_query = include_filters ? query.merge(active_filters: active_filters) : query
    cache_key = CacheKeyGenerator.call(cache_query)

    Rails.cache.fetch("#{SEARCH_RESULTS_CACHE_NAMESPACE}/#{cache_key}/#{@active_tab}",
                      expires_in: SEARCH_RESULTS_CACHE_TTL) do
      response = serialize_timdex_response(execute_timdex_query(query))
      errors = extract_errors(response)

      if errors.nil?
        hits = response.dig(:data, 'search', 'hits') || 0
        raw_results = extract_results(response)
        results = NormalizeTimdexResults.new(raw_results, @enhanced_query[:q]).normalize
        payload = { results: results, errors: nil, hits: hits }
        payload[:filters] = extract_filters(response) if include_filters
        payload
      else
        { results: [], errors: errors, hits: 0 }
      end
    end
  end

  # Collects FRBR group IDs found in Primo normalization to add to the log payload.
  def collect_frbr_group_ids(group_ids)
    return if group_ids.blank?

    @frbr_group_ids ||= []
    @frbr_group_ids.concat(group_ids)
  end

  def active_filters
    ENV.fetch('ACTIVE_FILTERS', '').split(',').map(&:strip).reject(&:blank?)
  end

  def query_primo(per_page, offset)
    Rails.logger.debug do
      "External Primo search request: tab=#{@active_tab}, offset=#{offset}, per_page=#{per_page}"
    end

    primo_search = PrimoSearch.new(@active_tab)
    primo_search.search(@enhanced_query[:q], per_page, offset)
  end

  def prepare_timdex_query(query)
    query[:sourceFilter] = ['MIT Libraries Website', 'LibGuides'] if @active_tab == 'website'
    query[:sourceFilter] = ['MIT ArchivesSpace'] if @active_tab == 'aspace'
    query[:sourceFilter] = ['MIT Alma'] if @active_tab == 'timdex_alma'
    query[:sourceFilter] = ['DSpace@MIT'] if @active_tab == 'dspace'
    query[:sourceFilter] = ['Research Databases'] if @active_tab == 'databases'
    query[:sourceFilter] = ['OpenGeoMetadata GIS Resources', 'MIT GIS Resources'] if @active_tab == 'geodata'
    query[:sourceFilter] = ['Digital Collections'] if @active_tab == 'digital_collections'
    query[:useGlobalScoring] = Feature.enabled?(:global_scoring)

    query
  end

  def execute_timdex_query(query)
    Rails.logger.debug do
      "External TIMDEX search request: tab=#{@active_tab}, from=#{query['from'] || 0}, per_page=#{query['perPage']}"
    end

    if Feature.enabled?(:geodata)
      execute_geospatial_query(query)
    else
      TimdexBase::Client.query(TimdexSearch::BaseQuery, variables: query)
    end
  end

  def serialize_timdex_response(raw)
    # The response type is a GraphQL::Client::Response, which is not directly serializable, so we
    # convert it to a hash.
    {
      data: raw.data.to_h,
      errors: raw.errors.details.to_h
    }
  end

  def execute_geospatial_query(query)
    query = query.except('queryMode')

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
    return unless Feature.enabled?(:geodata)

    return unless params[:geodistance]&.strip == 'true'

    geodistance_params = [params[:geodistanceLatitude]&.strip, params[:geodistanceLongitude]&.strip,
                          params[:geodistanceDistance]&.strip]
    return if geodistance_params.all?(&:present?)

    flash[:error] = 'All geospatial distance fields are required.'
    redirect_to root_url
  end

  def validate_geobox_presence!
    return unless Feature.enabled?(:geodata)

    return unless params[:geobox]&.strip == 'true'

    geobox_params = [params[:geoboxMinLatitude]&.strip, params[:geoboxMinLongitude]&.strip,
                     params[:geoboxMaxLatitude]&.strip, params[:geoboxMaxLongitude]&.strip]
    return if geobox_params.all?(&:present?)

    flash[:error] = 'All bounding box fields are required.'
    redirect_to root_url
  end

  def validate_geodistance_range!
    return unless Feature.enabled?(:geodata)

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
    return unless Feature.enabled?(:geodata)

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
    return unless Feature.enabled?(:geodata)

    return unless params[:geodistance]&.strip == 'true'

    distance = params[:geodistanceDistance]&.strip.to_i
    return if distance.positive?

    flash[:error] = 'Distance must include an integer greater than 0.'
    redirect_to root_url
  end

  def validate_geodistance_units!
    return unless Feature.enabled?(:geodata)

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
    return unless Feature.enabled?(:geodata)

    return unless params[:geobox]&.strip == 'true'

    geobox_lat = [params[:geoboxMinLatitude]&.strip.to_f, params[:geoboxMaxLatitude]&.strip.to_f]

    # Confirm that min latitude value is lower than max value.
    return if geobox_lat[0] < geobox_lat[1]

    flash[:error] = 'Maximum latitude cannot exceed minimum latitude.'
    redirect_to root_url
  end

  def handle_primo_errors(error)
    Rails.logger.error("Primo search error: #{error.class}: #{error.message}")

    # For timeouts, prompt users to try again.
    return [{ 'message' => 'Sorry, that took longer than expected. Please try your search again.' }] if error.is_a?(HTTP::TimeoutError)

    # For other errors, Primo is probably down, and we should direct users elsewhere.
    [{
      'code' => 'primo_unavailable',
      'message' => 'Hmm, we seem to be having difficulties...',
      'description' => 'In the meantime, try searching these tools directly.',
      'links' => [
        { 'label' => "MIT's WorldCat", 'description' => 'Books and media',
          'url' => 'https://libraries.mit.edu/worldcat' },
        { 'label' => 'Google Scholar', 'description' => 'Articles', 'url' => 'https://scholar.google.com/' },
        { 'label' => 'ArchivesSpace', 'description' => 'MIT archives', 'url' => 'https://archivesspace.mit.edu/' },
        { 'label' => 'DSpace@MIT', 'description' => 'MIT research', 'url' => 'https://dspace.mit.edu/' }
      ],
      'help_label' => 'Ask Us',
      'help_url' => 'https://libraries.mit.edu/ask/'
    }]
  end

  # authorized_request? handles the verification that a request is valid. This validity is enforced in different ways
  # based on the requested format. Requests for results in JSON format need to be accompanied with a valid token.
  # Requests for results in other formats (HTML, primarily) are subject to review by BotDetector and Turnstile.
  #
  # If the request if authorized, it returns true (allowing the application to generate a response)
  # If the request is not authorized, it either renders an unauthorized error, or redirects the user to Turnstile
  # (depending on the requested format)
  def authorized_request?
    if request.format.json?
      return true if format_tokens_defined? && valid_token?

      render json: { error: 'Unauthorized request' }, status: :unauthorized
    else
      return true unless Feature.enabled?(:bot_detection) # always pass if feature not enabled
      return true if session[:passed_turnstile]

      return true unless BotDetector.should_challenge?(request)

      redirect_to turnstile_path(return_to: request.fullpath)
    end
  end

  # format_tokens_defined? confirms whether a format token is defined in both the environment and query params.
  # Returns a boolean.
  def format_tokens_defined?
    return true if ENV.fetch('FORMAT_TOKEN', '').present? && params.key?(:format_token)

    false
  end

  # valid_token? confirms whether the token received from the user matches the one defined in the environment. Returns
  # a boolean.
  def valid_token?
    return true if ActiveSupport::SecurityUtils.secure_compare(params[:format_token], ENV.fetch('FORMAT_TOKEN', ''))

    false
  end

  # show_nls_warning? determines if the user should see a warning that results are not using natural language search.
  # Shows when: user is opted-in AND viewing a Primo-only tab (which only supports keyword search).
  def show_nls_warning?
    @natural_language_search_optin && primo_tabs.include?(@active_tab)
  end
end
