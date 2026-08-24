# Orchestrates merged "all" tab searches across Primo and TIMDEX.
#
# This service intentionally supports two execution modes:
#
# 1) Load-more mode: grows a cached candidate pool and reranks with the
#    reranker gem while preserving already-visible prefix order.
# 2) Legacy page mode: uses the historical zipper-style merge plan with
#    page/per_page offsets.
#
# The controller selects mode by passing either `display_count` (load-more)
# or `page`/`per_page` (legacy).
class MergedSearchService
  TTL = 12.hours

  # Initialize a new MergedSearchService.
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

  # Fetch all-tab results in either load-more or legacy page mode.
  #
  # @param display_count [Integer, nil] number of ordered results the caller
  #   wants visible after this request.
  # @param stable_count [Integer] number of leading results already displayed in
  #   the browser. Those records retain their relative order even if the expanded
  #   candidate pool would rerank them differently.
  # @param per_source [Integer, nil] number of results to request from each API
  #   per source fetch; defaults to ALL_TAB_RESULTS_PER_SOURCE or 50.
  # @param page [Integer, nil] legacy page number for traditional pagination.
  # @param per_page [Integer, nil] legacy page size.
  # @return [Hash] in load-more mode: :results, :append_results, :errors,
  #   :load_more. In legacy mode: :results, :errors, :pagination,
  #   :show_primo_continuation.
  def fetch(display_count: nil, stable_count: 0, per_source: nil, page: nil, per_page: nil)
    return fetch_legacy(page: page, per_page: per_page) if page.present?

    fetch_load_more(display_count: display_count, stable_count: stable_count, per_source: per_source)
  end

  # Load-more mode implementation.
  #
  # @param display_count [Integer, nil] number of ordered results the caller
  #   wants visible after this request.
  # @param stable_count [Integer] number of leading results already displayed in
  #   the browser. Those records retain their relative order even if the expanded
  #   candidate pool would rerank them differently.
  # @param per_source [Integer, nil] number of results to request from each API
  #   per source fetch; defaults to ALL_TAB_RESULTS_PER_SOURCE or 50.
  # @return [Hash] :results, :append_results, :errors, :load_more where
  #   :load_more includes :display_count, :next_count, :has_more, and :total_hits.
  #
  # Maintains per-query state in cache, fetches additional source chunks as
  # needed, reranks globally, and returns only the newly appended slice.
  def fetch_load_more(display_count:, stable_count:, per_source:)
    per_source = (per_source || ENV.fetch('ALL_TAB_RESULTS_PER_SOURCE', '50')).to_i
    display_count = (display_count || ENV.fetch('RESULTS_PER_PAGE', '20')).to_i
    display_count = [display_count, 1].max
    stable_count = [stable_count.to_i, 0].max
    cache_key = state_cache_key(per_source: per_source)

    state = Rails.cache.read(cache_key) || empty_state
    state = ensure_ordered_results(state, display_count: display_count, stable_count: stable_count,
                                          per_source: per_source)
    Rails.cache.write(cache_key, state, expires_in: TTL)

    ordered_results = records_for_keys(state[:ordered_keys], state).first(display_count)
    append_results = ordered_results[stable_count...display_count] || []
    total_hits = state[:primo_hits].to_i + state[:timdex_hits].to_i

    {
      results: ordered_results,
      append_results: append_results,
      errors: state[:errors],
      load_more: {
        display_count: display_count,
        next_count: display_count + visible_batch_size,
        has_more: has_more?(state, display_count),
        total_hits: total_hits
      }
    }
  end

  # Legacy all-tab merged pagination based on page/per_page. This keeps the
  # original behavior available while the load-more mode is feature flagged.
  #
  # @param page [Integer, nil] legacy page number for traditional pagination.
  # @param per_page [Integer, nil] legacy page size.
  # @return [Hash] :results, :errors, :pagination, :show_primo_continuation.
  #
  # Returns the historical merged-page payload expected by legacy templates.
  def fetch_legacy(page:, per_page:)
    current_page = (page || 1).to_i
    per_page = (per_page || ENV.fetch('RESULTS_PER_PAGE', '20')).to_i
    if current_page == 1
      first_page_fetch_legacy(current_page, per_page)
    else
      deeper_page_fetch_legacy(current_page, per_page)
    end
  end

  private

  def first_page_fetch_legacy(current_page, per_page)
    primo_data, timdex_data = parallel_fetch_legacy(offset: 0, per_page: per_page)

    totals = { primo: primo_data[:hits].to_i, timdex: timdex_data[:hits].to_i }
    write_cached_totals_legacy(totals)

    paginator = build_paginator_from_totals_legacy(totals, current_page, per_page)

    assemble_all_tab_result_legacy(paginator, primo_data, timdex_data, current_page, per_page)
  end

  def deeper_page_fetch_legacy(current_page, per_page)
    totals = Rails.cache.read(totals_cache_key_legacy)

    unless totals
      primo_summary, timdex_summary = parallel_fetch_legacy(offset: 0, per_page: 1)
      totals = { primo: primo_summary[:hits].to_i, timdex: timdex_summary[:hits].to_i }
      write_cached_totals_legacy(totals)
    end

    paginator = build_paginator_from_totals_legacy(totals, current_page, per_page)
    primo_data, timdex_data = fetch_all_tab_page_chunks_legacy(paginator)

    assemble_all_tab_result_legacy(paginator, primo_data, timdex_data, current_page, per_page, deeper: true)
  end

  def totals_cache_key_legacy
    base = CacheKeyGenerator.call(@enhanced_query.merge(tab: @active_tab))
    "#{base}/totals/legacy"
  end

  def write_cached_totals_legacy(totals)
    Rails.cache.write(totals_cache_key_legacy, totals, expires_in: TTL)
  end

  def parallel_fetch_legacy(offset:, per_page:)
    primo = nil
    timdex = nil
    threads = []
    threads << Thread.new { primo = @primo_fetcher.call(offset: offset, per_page: per_page, query: @enhanced_query) }
    threads << Thread.new { timdex = @timdex_fetcher.call(offset: offset, per_page: per_page, query: @enhanced_query) }
    threads.each(&:join)
    [primo, timdex]
  end

  def fetch_all_tab_page_chunks_legacy(paginator)
    merge_plan = paginator.merge_plan
    primo_count = merge_plan.count(:primo)
    timdex_count = merge_plan.count(:timdex)
    primo_offset, timdex_offset = paginator.api_offsets

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
                   { results: [], errors: nil, hits: paginator.primo_total, show_continuation: false }
                 end
    timdex_data = if timdex_thread
                    timdex_thread.value
                  else
                    { results: [], errors: nil, hits: paginator.timdex_total }
                  end

    [primo_data, timdex_data]
  end

  def assemble_all_tab_result_legacy(paginator, primo_data, timdex_data, current_page, per_page, deeper: false)
    primo_total = primo_data[:hits] || 0
    timdex_total = timdex_data[:hits] || 0

    merged = merge_results_legacy(paginator, primo_data[:results] || [], timdex_data[:results] || [])
    errors = combine_errors(primo_data[:errors], timdex_data[:errors])
    pagination = Analyzer.new(@enhanced_query, timdex_total, :all, primo_total, per_page).pagination

    show_primo_continuation = if deeper
                                primo_api_offset, = paginator.api_offsets
                                primo_data[:show_continuation] ||
                                  (primo_api_offset && primo_api_offset >= Analyzer::PRIMO_MAX_OFFSET) ||
                                  (primo_api_offset.nil? && ((current_page - 1) * per_page) >= Analyzer::PRIMO_MAX_OFFSET)
                              else
                                primo_data[:show_continuation]
                              end

    { results: merged, errors: errors, pagination: pagination, show_primo_continuation: show_primo_continuation }
  end

  def build_paginator_from_totals_legacy(totals, current_page, per_page)
    MergedSearchPaginator.new(primo_total: totals[:primo] || 0, timdex_total: totals[:timdex] || 0,
                              current_page: current_page, per_page: per_page)
  end

  def merge_results_legacy(paginator, primo_results, timdex_results)
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

  # Returns an empty serializable cache state for a merged all-tab search.
  # Source result arrays hold normalized records. `ordered_keys` is the stable
  # display order, represented by deterministic record keys so duplicated
  # records can be removed safely when additional source chunks arrive.
  def empty_state
    {
      primo_results: [],
      timdex_results: [],
      ordered_keys: [],
      primo_hits: 0,
      timdex_hits: 0,
      primo_exhausted: false,
      timdex_exhausted: false,
      errors: nil
    }
  end

  # Ensures the cached state contains enough ordered results to satisfy the
  # requested display count, fetching more source candidates when necessary.
  def ensure_ordered_results(state, display_count:, stable_count:, per_source:)
    state = rerank_state(state, stable_count: stable_count) if state[:ordered_keys].empty? && any_results?(state)

    while state[:ordered_keys].length < display_count && sources_available?(state)
      previous_count = state[:ordered_keys].length
      state = fetch_next_source_chunks(state, per_source: per_source)
      state = rerank_state(state, stable_count: stable_count)
      break if state[:ordered_keys].length == previous_count
    end

    state
  end

  # Fetches the next chunk from each source that can still produce records. The
  # source offset is simply the number of normalized records already cached for
  # that source, which preserves each API's native offset semantics while the
  # service manages display order separately.
  def fetch_next_source_chunks(state, per_source:)
    primo_offset = state[:primo_results].length
    timdex_offset = state[:timdex_results].length

    primo_data, timdex_data = parallel_fetch(
      primo_offset: state[:primo_exhausted] || primo_offset >= Analyzer::PRIMO_MAX_OFFSET ? nil : primo_offset,
      timdex_offset: state[:timdex_exhausted] ? nil : timdex_offset,
      per_page: per_source
    )

    update_state_from_source!(state, :primo, primo_data, requested_offset: primo_offset, per_page: per_source)
    update_state_from_source!(state, :timdex, timdex_data, requested_offset: timdex_offset, per_page: per_source)
    state[:errors] = combine_errors(state[:errors], primo_data&.[](:errors), timdex_data&.[](:errors))

    state
  end

  # Merges a source response into the cached state and records whether that
  # source appears exhausted. A source is exhausted when it returns fewer records
  # than requested, reports no more total hits, contributes only previously seen
  # records, or Primo signals continuation.
  def update_state_from_source!(state, source, data, requested_offset:, per_page:)
    return mark_exhausted!(state, source, reason: 'fetch skipped') if data.nil?

    results_key = source_results_key(source)
    hits_key = source_hits_key(source)
    incoming = Array(data[:results])
    previous_length = state[results_key].length

    state[hits_key] = data[:hits].to_i
    state[results_key] = dedupe_records(state[results_key] + incoming)

    if incoming.any? && state[results_key].length == previous_length
      return mark_exhausted!(state, source, reason: 'duplicate-only response', offset: requested_offset,
                                            returned: incoming.length, hits: state[hits_key])
    end

    exhaustion_reason = exhaustion_reason(data, incoming, requested_offset, per_page, state[hits_key])
    return unless exhaustion_reason

    mark_exhausted!(state, source, reason: exhaustion_reason, offset: requested_offset,
                                   returned: incoming.length, hits: state[hits_key])
  end

  def mark_exhausted!(state, source, reason:, offset: nil, returned: nil, hits: nil)
    state[:"#{source}_exhausted"] = true
    Rails.logger.debug do
      details = { source: source, reason: reason, offset: offset, returned: returned, hits: hits }.compact
      "All-tab load more exhausted source: #{details}"
    end
  end

  # Returns a short reason string when a source can no longer provide useful
  # load-more candidates, or nil while the source should remain available.
  def exhaustion_reason(data, incoming, requested_offset, per_page, hits)
    return 'Primo continuation required' if data[:show_continuation]
    return 'empty response' if incoming.empty?
    return 'short response' if incoming.length < per_page
    return 'reported hits reached' if hits.to_i.positive? && requested_offset + incoming.length >= hits.to_i

    nil
  end

  # Fetch from Primo and TIMDEX concurrently.
  #
  # WARNING: exceptions raised inside threads do not automatically propagate;
  # callers should account for this.
  #
  # @param primo_offset [Integer, nil] next Primo offset, or nil to skip Primo
  # @param timdex_offset [Integer, nil] next TIMDEX offset, or nil to skip TIMDEX
  # @param per_page [Integer] number of results to request per source
  # @return [Array<Hash, Hash>] [primo_response, timdex_response]
  def parallel_fetch(primo_offset:, timdex_offset:, per_page:)
    primo = nil
    timdex = nil
    threads = []
    if primo_offset && primo_offset < Analyzer::PRIMO_MAX_OFFSET
      threads << Thread.new do
        primo = @primo_fetcher.call(offset: primo_offset, per_page: per_page, query: @enhanced_query)
      end
    end
    if timdex_offset
      threads << Thread.new do
        timdex = @timdex_fetcher.call(offset: timdex_offset, per_page: per_page, query: @enhanced_query)
      end
    end
    threads.each(&:join)
    [primo, timdex]
  end

  # Reranks the expanded candidate pool and preserves any already-visible prefix.
  # This method intentionally treats the reranker as an interchangeable ordering
  # engine: any scorer that returns ordered result hashes through the gem's
  # stable API can be used without changing the load-more logic.
  def rerank_state(state, stable_count:)
    prefix = state[:ordered_keys].first(stable_count)
    reranked = Reranker::Reranker.new(configured_scorer).rerank(
      state[:primo_results], state[:timdex_results], query: @enhanced_query[:q]
    )
    reranked_keys = dedupe_keys(reranked.map { |record| record_key(record) })

    state[:ordered_keys] = prefix + reranked_keys.reject { |key| prefix.include?(key) }
    state
  end

  # Instantiate the scorer based on the ALL_TAB_SCORER env var.
  # Defaults to ZipperMergeScorer.
  #
  # @return [Reranker::Scorer]
  def configured_scorer
    case ENV.fetch('ALL_TAB_SCORER', 'zipper').downcase
    when 'zscore' then Reranker::ZscoreScorer.new
    when 'zipper' then Reranker::ZipperMergeScorer.new
    when 'simple' then Reranker::SimpleScorer.new
    when 'random' then Reranker::RandomScorer.new
    else Reranker::ZipperMergeScorer.new
    end
  end

  def state_cache_key(per_source:)
    query = @enhanced_query.except(:page).merge(
      tab: @active_tab,
      scorer: ENV.fetch('ALL_TAB_SCORER', 'zipper'),
      boost_sources: ENV.fetch('ALL_TAB_BOOST_SOURCES', ''),
      per_source: per_source.to_i
    )
    "#{CacheKeyGenerator.call(query)}/all-tab-load-more"
  end

  def visible_batch_size
    ENV.fetch('RESULTS_PER_PAGE', '20').to_i
  end

  def any_results?(state)
    state[:primo_results].any? || state[:timdex_results].any?
  end

  def sources_available?(state)
    !state[:primo_exhausted] || !state[:timdex_exhausted]
  end

  def has_more?(state, display_count)
    state[:ordered_keys].length > display_count || sources_available?(state)
  end

  def source_results_key(source)
    :"#{source}_results"
  end

  def source_hits_key(source)
    :"#{source}_hits"
  end

  def records_for_keys(keys, state)
    records_by_key = (state[:primo_results] + state[:timdex_results]).index_by { |record| record_key(record) }
    keys.filter_map { |key| records_by_key[key] }
  end

  def dedupe_records(records)
    records.reverse.index_by { |record| record_key(record) }.values.reverse
  end

  def dedupe_keys(keys)
    keys.each_with_object([]) { |key, unique| unique << key unless unique.include?(key) }
  end

  def record_key(record)
    [record[:api], record[:identifier] || record[:sourceLink] || record[:source_link] || record[:title]].join(':')
  end

  # Merge multiple error arrays into a single array, or nil when empty.
  #
  # @return [Array, nil]
  def combine_errors(*error_arrays)
    all_errors = error_arrays.compact.flatten
    all_errors.any? ? all_errors : nil
  end
end
