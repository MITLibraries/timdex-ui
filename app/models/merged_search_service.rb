require 'digest'

# Orchestrates merged "all" tab searches across Primo and TIMDEX.
#
# Handles parallel fetches, per-query totals caching, pagination calculation via
# `MergedSearchPaginator`, and assembly of a controller-friendly response hash.
class MergedSearchService
  # Time to live value for cache expiration.
  TTL = 12.hours

  # Initialize a new MergedSearchService.
  #
  # The service requires two callable fetchers (for Primo and TIMDEX) that
  # perform the underlying source requests. Fetchers are injected to keep
  # the orchestration logic decoupled from transport, caching, and
  # normalization concerns.
  #
  # @param enhanced_query [Hash] query hash produced by `Enhancer`
  # @param active_tab [String] the currently active tab (e.g. 'all')
  # @param primo_fetcher [#call] callable used to fetch Primo results; must accept `offset:, per_page:, query:`
  # @param timdex_fetcher [#call] callable used to fetch TIMDEX results; must accept `offset:, per_page:, query:`
  def initialize(enhanced_query:, active_tab:, primo_fetcher:, timdex_fetcher:)
    @enhanced_query = enhanced_query
    @active_tab = active_tab
    @primo_fetcher = primo_fetcher
    @timdex_fetcher = timdex_fetcher
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
      first_page_fetch(current_page, per_page)
    else
      deeper_page_fetch(current_page, per_page)
    end
  end

  # Handle page 1: perform the full-size parallel fetch, cache
  # totals, build the paginator, and return the assembled result.
  #
  # Executes a full-size parallel fetch (requests `per_page` items from each
  # backend), computes and caches per-query totals, constructs a
  # `MergedSearchPaginator`, and assembles the controller-facing response.
  #
  # @param current_page [Integer] the current page (expected to be 1)
  # @param per_page [Integer] the number of results per merged page
  # @return [Hash] keys: :results, :errors, :pagination, :show_primo_continuation
  def first_page_fetch(current_page, per_page)
    primo_data, timdex_data = parallel_fetch(offset: 0, per_page: per_page)

    totals = { primo: primo_data[:hits].to_i, timdex: timdex_data[:hits].to_i }
    write_cached_totals(totals)

    paginator = build_paginator_from_totals(totals, current_page, per_page)

    assemble_all_tab_result(paginator, primo_data, timdex_data, current_page, per_page)
  end

  # Handle deeper pages: ensure totals are available (falling back to summary
  # calls when missing), build the paginator, fetch required chunks, and
  # assemble the final result.
  #
  # Ensures per-query totals are available by reading cached totals or
  # performing summary requests (per_page == 1) if the cached totals aren't
  # present. (They should be, but there may be edge cases.)
  # Builds a `MergedSearchPaginator`, fetches the page-sized chunks required
  # for the merged layout, and returns the assembled controller-facing response.
  #
  # @param current_page [Integer] the requested page number (> 1)
  # @param per_page [Integer] the number of results per merged page
  # @return [Hash] keys: :results, :errors, :pagination, :show_primo_continuation
  def deeper_page_fetch(current_page, per_page)
    totals = Rails.cache.read(totals_cache_key)

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

  # Persist per-query totals to the application cache.
  #
  # Tests use a test-local `Rails.cache` (MemoryStore) so they do not need to
  # inject a separate cache instance; production code uses the configured
  # `Rails.cache` store.
  #
  # @param totals [Hash] { primo: Integer, timdex: Integer }
  def write_cached_totals(totals)
    Rails.cache.write(totals_cache_key, totals, expires_in: TTL)
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

    # Only spawn fetch threads when we both need results for the merge plan
    # and the paginator indicates a valid offset for that API. A `nil` offset
    # means the API is exhausted and should not be queried for this page.
    primo_thread = if primo_count > 0 && !primo_offset.nil?
                     Thread.new do
                       @primo_fetcher.call(offset: primo_offset, per_page: primo_count, query: @enhanced_query)
                     end
                   end
    timdex_thread = if timdex_count > 0 && !timdex_offset.nil?
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

    merged = merge_results(paginator, primo_data[:results] || [], timdex_data[:results] || [])
    errors = combine_errors(primo_data[:errors], timdex_data[:errors])
    pagination = Analyzer.new(@enhanced_query, timdex_total, :all, primo_total, per_page).pagination

    show_primo_continuation = if deeper
                                # Use the Primo-specific API offset (calculated from the paginator)
                                # when deciding whether to show a Primo continuation.
                                #
                                # If the paginator returns `nil` for a exhausted API we still
                                # want to show the continuation when the requested page is far
                                # beyond the Primo API's practical offset limit. Fall back to
                                # checking the merged page's start index when the API offset
                                # is unavailable.
                                primo_api_offset, _timdex_api_offset = paginator.api_offsets
                                primo_data[:show_continuation] ||
                                  (primo_api_offset && primo_api_offset >= Analyzer::PRIMO_MAX_OFFSET) ||
                                  (primo_api_offset.nil? && ((current_page - 1) * per_page) >= Analyzer::PRIMO_MAX_OFFSET)
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

  # Note: default fetcher implementations were removed to enforce explicit
  # dependency injection. Callers must provide `primo_fetcher` and
  # `timdex_fetcher` when constructing `MergedSearchService`.

  # Generate a cache key based on the supplied query hash.
  #
  # @param query [Hash]
  # @return [String] MD5 hex digest
  def generate_cache_key(query)
    CacheKeyGenerator.call(query)
  end

  # Helps callers (including `MergedSearchPaginator`) delegate merging logic to the orchestration
  # layer. This method iterates the paginator's `merge_plan` and pulls items from the respective
  # source result arrays in order.
  #
  # @param paginator [MergedSearchPaginator]
  # @param primo_results [Array]
  # @param timdex_results [Array]
  # @return [Array] merged results
  def merge_results(paginator, primo_results, timdex_results)
    merged = []
    primo_idx = 0
    timdex_idx = 0
    paginator.merge_plan.each do |source|
      if source == :primo
        merged << primo_results[primo_idx] if primo_idx < primo_results.length
        primo_idx += 1
      else
        merged << timdex_results[timdex_idx] if timdex_idx < timdex_results.length
        timdex_idx += 1
      end
    end
    merged
  end
end
