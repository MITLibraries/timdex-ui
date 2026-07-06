# Orchestrates merged "all" tab searches across Primo and TIMDEX using the
# reranker gem. Fetches a configurable number of results from each source in
# parallel, then delegates ordering to the configured scorer.
class MergedSearchService
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

  # Fetch and rerank results from both sources.
  #
  # @param per_source [Integer, nil] number of results to request from each API;
  #   defaults to the ALL_TAB_RESULTS_PER_SOURCE env var (or 50).
  # @return [Hash] keys: :results, :errors
  def fetch(per_source: nil)
    per_source = (per_source || ENV.fetch('ALL_TAB_RESULTS_PER_SOURCE', '50')).to_i
    primo_data, timdex_data = parallel_fetch(per_page: per_source)

    primo_results = primo_data[:results] || []
    timdex_results = timdex_data[:results] || []
    errors = combine_errors(primo_data[:errors], timdex_data[:errors])

    merged = Reranker::Reranker.new(configured_scorer).rerank(
      primo_results, timdex_results, query: @enhanced_query[:q]
    )

    { results: merged, errors: errors }
  end

  private

  # Fetch from Primo and TIMDEX concurrently.
  #
  # WARNING: exceptions raised inside threads do not automatically propagate;
  # callers should account for this.
  #
  # @param per_page [Integer] number of results to request per source
  # @return [Array<Hash, Hash>] [primo_response, timdex_response]
  def parallel_fetch(per_page:)
    primo = nil
    timdex = nil
    threads = [
      Thread.new { primo = @primo_fetcher.call(offset: 0, per_page: per_page, query: @enhanced_query) },
      Thread.new { timdex = @timdex_fetcher.call(offset: 0, per_page: per_page, query: @enhanced_query) }
    ]
    threads.each(&:join)
    [primo, timdex]
  end

  # Instantiate the scorer based on the ALL_TAB_SCORER env var.
  # Defaults to ZscoreScorer.
  #
  # @return [Reranker::Scorer]
  def configured_scorer
    case ENV.fetch('ALL_TAB_SCORER', 'zscore').downcase
    when 'zscore'  then Reranker::ZscoreScorer.new
    when 'zipper'  then Reranker::ZipperMergeScorer.new
    when 'simple'  then Reranker::SimpleScorer.new
    when 'random'  then Reranker::RandomScorer.new
    else                Reranker::ZscoreScorer.new
    end
  end

  # Merge multiple error arrays into a single array, or nil when empty.
  #
  # @return [Array, nil]
  def combine_errors(*error_arrays)
    all_errors = error_arrays.compact.flatten
    all_errors.any? ? all_errors : nil
  end
end
