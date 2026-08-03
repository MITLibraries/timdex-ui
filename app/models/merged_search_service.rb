# Orchestrates merged "all" tab searches across Primo and TIMDEX using the
# reranker gem.
#
# The all tab cannot use traditional page numbers because each "load more"
# request may add new candidates from both source APIs and reranking that larger
# pool can change global order. To keep the user experience stable, this service
# caches a per-query candidate pool and ordered list of record keys. When the
# pool grows, it reranks everything again but preserves the prefix the browser
# has already displayed, appending only unseen records after that prefix.
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

  # Fetch and rerank results from both sources for the all tab.
  #
  # @param display_count [Integer, nil] number of ordered results the caller
  #   wants visible after this request.
  # @param stable_count [Integer] number of leading results already displayed in
  #   the browser. Those records retain their relative order even if the expanded
  #   candidate pool would rerank them differently.
  # @param per_source [Integer, nil] number of results to request from each API
  #   per source fetch; defaults to ALL_TAB_RESULTS_PER_SOURCE or 50.
  # @return [Hash] keys: :results, :append_results, :errors, :load_more
  def fetch(display_count: nil, stable_count: 0, per_source: nil)
    per_source = (per_source || ENV.fetch('ALL_TAB_RESULTS_PER_SOURCE', '50')).to_i
    display_count = (display_count || ENV.fetch('RESULTS_PER_PAGE', '20')).to_i
    display_count = [display_count, 1].max
    stable_count = [stable_count.to_i, 0].max

    state = Rails.cache.read(state_cache_key) || empty_state
    state = ensure_ordered_results(state, display_count: display_count, stable_count: stable_count,
                                          per_source: per_source)
    Rails.cache.write(state_cache_key, state, expires_in: TTL)

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

  private

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
  # than requested, reports no more total hits, or Primo signals continuation.
  def update_state_from_source!(state, source, data, requested_offset:, per_page:)
    return mark_exhausted!(state, source, reason: 'fetch skipped') if data.nil?

    results_key = source_results_key(source)
    hits_key = source_hits_key(source)
    incoming = Array(data[:results])

    state[hits_key] = data[:hits].to_i
    state[results_key] = dedupe_records(state[results_key] + incoming)

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
    when 'zscore'  then Reranker::ZscoreScorer.new
    when 'zipper'  then Reranker::ZipperMergeScorer.new
    when 'simple'  then Reranker::SimpleScorer.new
    when 'random'  then Reranker::RandomScorer.new
    else                Reranker::ZscoreScorer.new
    end
  end

  def state_cache_key
    query = @enhanced_query.except(:page).merge(
      tab: @active_tab,
      scorer: ENV.fetch('ALL_TAB_SCORER', 'zscore'),
      boost_sources: ENV.fetch('ALL_TAB_BOOST_SOURCES', ''),
      per_source: ENV.fetch('ALL_TAB_RESULTS_PER_SOURCE', '50')
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
