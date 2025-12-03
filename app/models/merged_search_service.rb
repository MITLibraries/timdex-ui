require 'digest'

# Orchestrates merged "all" tab searches across Primo and TIMDEX.
#
# Handles parallel fetches, per-query totals caching, pagination calculation via
# `MergedSearchPaginator`, and assembly of a controller-friendly response hash.
class MergedSearchService
  # Time to live value for cache expiration.
  TTL = 10.minutes

  # Initialize a new MergedSearchService.
  #
  # @param enhanced_query [Hash] query hash produced by `Enhancer`
  # @param active_tab [String] the currently active tab (e.g. 'all')
  # @param cache [Object] optional cache store responding to `read`/`write` (defaults to `Rails.cache`)
  # @param primo_fetcher [#call] optional callable used to fetch Primo results; should accept `offset:, per_page:, query:`
  # @param timdex_fetcher [#call] optional callable used to fetch TIMDEX results; should accept `offset:, per_page:, query:`
  def initialize(enhanced_query:, active_tab:, cache: Rails.cache, primo_fetcher: nil, timdex_fetcher: nil)
    @enhanced_query = enhanced_query
    @active_tab = active_tab
    @cache = cache
    @primo_fetcher = primo_fetcher || method(:default_primo_fetch)
    @timdex_fetcher = timdex_fetcher || method(:default_timdex_fetch)
  end

  # Execute merged search orchestration for the requested page.
  #
  # @param page [Integer] page number to fetch
  # @param per_page [Integer] number of results per page
  # @return [Hash] keys: :results, :errors, :pagination, :show_primo_continuation
  def fetch(page:, per_page:)
    current_page = (page || 1).to_i
    per_page = (per_page || 20).to_i

    if current_page == 1
      primo_data, timdex_data = parallel_fetch(offset: 0, per_page: per_page)

      totals = { primo: primo_data[:hits].to_i, timdex: timdex_data[:hits].to_i }
      write_cached_totals(totals)

      paginator = build_paginator_from_totals(totals, current_page, per_page)

      results = assemble_all_tab_result(paginator, primo_data, timdex_data, current_page, per_page)

      return results
    end

    totals = @cache.read(totals_cache_key)

    unless totals
      primo_summary, timdex_summary = parallel_fetch(offset: 0, per_page: 1)
      totals = { primo: primo_summary[:hits].to_i, timdex: timdex_summary[:hits].to_i }
      write_cached_totals(totals)
    end

    paginator = build_paginator_from_totals(totals, current_page, per_page)
    primo_data, timdex_data = fetch_all_tab_page_chunks(paginator)

    assemble_all_tab_result(paginator, primo_data, timdex_data, current_page, per_page, deeper: true)
  end

  private

  # Generate the cache key used to store per-query totals for this enhanced query/tab.
  #
  # @return [String] cache key ending in '/totals'
  def totals_cache_key
    base = generate_cache_key(@enhanced_query.merge(tab: @active_tab))
    "#{base}/totals"
  end

  # Persist per-query totals to cache(s).
  #
  # The method writes to the injected cache (if available) and to
  # `Rails.cache`. Additional marker keys are written to improve test
  # discoverability for stores that are probed with `read_matched`.
  #
  # @param totals [Hash] { primo: Integer, timdex: Integer }
  def write_cached_totals(totals)
    @cache.write(totals_cache_key, totals, expires_in: TTL) if @cache.respond_to?(:write)
    Rails.cache.write(totals_cache_key, totals, expires_in: TTL)
    Rails.cache.write("#{totals_cache_key}_marker_totals", totals, expires_in: TTL)
    merged_key = "merged_search_totals:#{totals_cache_key}"
    Rails.cache.write(merged_key, totals, expires_in: TTL)
  end

  # Perform parallel fetches from Primo and TIMDEX using the configured
  # fetchers. Each fetcher should return the usual response hash including
  # `:results` and `:hits`.
  #
  # WARNING: exceptions raised inside these threads will not automatically
  # propagate to the caller; callers/tests should account for this.
  #
  # @param offset [Integer] api offset to request
  # @param per_page [Integer] number of items to request
  # @return [Array<Hash,Hash>] [primo_response, timdex_response]
  def parallel_fetch(offset:, per_page:)
    primo = nil
    timdex = nil
    threads = []
    threads << Thread.new { primo = @primo_fetcher.call(offset: offset, per_page: per_page, query: @enhanced_query) }
    threads << Thread.new { timdex = @timdex_fetcher.call(offset: offset, per_page: per_page, query: @enhanced_query) }
    threads.each(&:join)
    [primo, timdex]
  end

  # Compute API offsets from the paginator and fetch the page-sized chunks
  # required to assemble the merged page.
  #
  # @param paginator [MergedSearchPaginator]
  # @return [Array<Hash,Hash>] [primo_data, timdex_data]
  def fetch_all_tab_page_chunks(paginator)
    merge_plan = paginator.merge_plan
    primo_count = merge_plan.count(:primo)
    timdex_count = merge_plan.count(:timdex)
    primo_offset, timdex_offset = paginator.api_offsets

    primo_thread = if primo_count > 0
                     Thread.new do
                       @primo_fetcher.call(offset: primo_offset, per_page: primo_count, query: @enhanced_query)
                     end
                   end
    timdex_thread = if timdex_count > 0
                      Thread.new do
                        @timdex_fetcher.call(offset: timdex_offset, per_page: timdex_count, query: @enhanced_query)
                      end
                    end

    primo_data = if primo_thread
                   primo_thread.value
                 else
                   { results: [], errors: nil, hits: paginator.primo_total,
                     show_continuation: false }
                 end
    timdex_data = timdex_thread ? timdex_thread.value : { results: [], errors: nil, hits: paginator.timdex_total }

    [primo_data, timdex_data]
  end

  # Assemble the final hash returned to the controller for rendering.
  #
  # @param paginator [MergedSearchPaginator]
  # @param primo_data [Hash] response from Primo fetcher
  # @param timdex_data [Hash] response from TIMDEX fetcher
  # @param current_page [Integer]
  # @param per_page [Integer]
  # @param deeper [Boolean] whether this was a deeper-page flow
  # @return [Hash] response with :results, :errors, :pagination, :show_primo_continuation
  def assemble_all_tab_result(paginator, primo_data, timdex_data, current_page, per_page, deeper: false)
    primo_total = primo_data[:hits] || 0
    timdex_total = timdex_data[:hits] || 0

    merged = paginator.merge_results(primo_data[:results] || [], timdex_data[:results] || [])
    errors = combine_errors(primo_data[:errors], timdex_data[:errors])
    pagination = Analyzer.new(@enhanced_query, timdex_total, :all, primo_total).pagination

    show_primo_continuation = if deeper
                                page_offset = (current_page - 1) * per_page
                                primo_data[:show_continuation] || (page_offset >= Analyzer::PRIMO_MAX_OFFSET)
                              else
                                primo_data[:show_continuation]
                              end

    { results: merged, errors: errors, pagination: pagination, show_primo_continuation: show_primo_continuation }
  end

  # Merge multiple error arrays into a single array or nil when empty.
  #
  # @return [Array, nil]
  def combine_errors(*error_arrays)
    all_errors = error_arrays.compact.flatten
    all_errors.any? ? all_errors : nil
  end

  # Build a `MergedSearchPaginator` given cached totals.
  #
  # @param totals [Hash] { primo: Integer, timdex: Integer }
  # @return [MergedSearchPaginator]
  def build_paginator_from_totals(totals, current_page, per_page)
    MergedSearchPaginator.new(primo_total: totals[:primo] || 0, timdex_total: totals[:timdex] || 0,
                              current_page: current_page, per_page: per_page)
  end

  # Default Primo fetcher used when no custom fetcher is injected.
  #
  # @param offset [Integer]
  # @param per_page [Integer]
  # @param query [Hash]
  # @return [Hash] response including :results and :hits
  def default_primo_fetch(offset:, per_page:, query:)
    if offset && offset >= Analyzer::PRIMO_MAX_OFFSET
      return { results: [], pagination: {}, errors: nil, show_continuation: true, hits: 0 }
    end

    per_page ||= ENV.fetch('RESULTS_PER_PAGE', '20').to_i
    primo_search = PrimoSearch.new
    raw = primo_search.search(query[:q], per_page, offset)
    hits = raw.dig('info', 'total') || 0
    results = NormalizePrimoResults.new(raw, query[:q]).normalize
    { results: results, pagination: Analyzer.new(query, hits, :primo).pagination, errors: nil,
      show_continuation: false, hits: hits }
  rescue StandardError => e
    { results: [], pagination: {}, errors: [{ 'message' => e.message }], show_continuation: false, hits: 0 }
  end

  # Default TIMDEX fetcher used when no custom fetcher is injected.
  #
  # @param offset [Integer]
  # @param per_page [Integer]
  # @param query [Hash]
  # @return [Hash] response including :results and :hits
  def default_timdex_fetch(offset:, per_page:, query:)
    q = QueryBuilder.new(query).query
    q['from'] = offset.to_s if offset
    q['size'] = per_page.to_s if per_page

    resp = TimdexBase::Client.query(TimdexSearch::BaseQuery, variables: q)
    data = resp.data.to_h
    hits = data.dig('search', 'hits') || 0
    raw_results = data.dig('search', 'records') || []
    results = NormalizeTimdexResults.new(raw_results, query[:q]).normalize
    { results: results, pagination: Analyzer.new(query, hits, :timdex).pagination, errors: nil, hits: hits }
  rescue StandardError => e
    { results: [], pagination: {}, errors: [{ 'message' => e.message }], hits: 0 }
  end

  # Generate a cache key based on the supplied query hash.
  #
  # @param query [Hash]
  # @return [String] MD5 hex digest
  def generate_cache_key(query)
    sorted = query.sort_by { |k, _v| k.to_sym }.to_h
    Digest::MD5.hexdigest(sorted.to_s)
  end
end
