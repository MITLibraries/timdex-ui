require 'test_helper'

class MergedSearchServiceTest < ActiveSupport::TestCase
  test 'fetch writes state cache with source hit totals' do
    query = { q: 'test' }

    primo_fetcher = lambda do |offset:, per_page:, query:|
      { results: [{ title: 'P1', score: 0.9, api: 'primo', identifier: 'p1' }], hits: 42, errors: nil,
        show_continuation: false }
    end

    timdex_fetcher = lambda do |offset:, per_page:, query:|
      { results: [{ title: 'T1', score: 0.8, api: 'timdex', identifier: 't1' }], hits: 37, errors: nil }
    end

    service = MergedSearchService.new(enhanced_query: query, active_tab: 'all',
                                      primo_fetcher: primo_fetcher, timdex_fetcher: timdex_fetcher)

    res = service.fetch(display_count: 20)
    assert_equal 2, res[:results].length

    # Verify cache written
    key = service.send(:state_cache_key)
    cached = Rails.cache.read(key)
    refute_nil cached
    assert_equal 42, cached[:primo_hits]
    assert_equal 37, cached[:timdex_hits]
  end

  test 'fetch uses cached state when enough ordered results already exist' do
    query = { q: 'test' }

    # Fetchers that would raise if the service attempted to fetch despite a
    # cache hit with enough ordered results.
    primo_fetcher = lambda do |offset:, per_page:, query:|
      raise 'Unexpected Primo fetch'
    end

    timdex_fetcher = lambda do |offset:, per_page:, query:|
      raise 'Unexpected TIMDEX fetch'
    end

    service = MergedSearchService.new(enhanced_query: query, active_tab: 'all',
                                      primo_fetcher: primo_fetcher, timdex_fetcher: timdex_fetcher)

    cached_state = {
      primo_results: [{ title: 'P1', score: 0.9, api: 'primo', identifier: 'p1' }],
      timdex_results: [{ title: 'T1', score: 0.8, api: 'timdex', identifier: 't1' }],
      ordered_keys: %w[primo:p1 timdex:t1],
      primo_hits: 50,
      timdex_hits: 50,
      primo_exhausted: false,
      timdex_exhausted: false,
      errors: nil
    }
    Rails.cache.write(service.send(:state_cache_key), cached_state)

    # Should not raise
    assert_nothing_raised do
      res = service.fetch(display_count: 2, stable_count: 0)
      assert res[:results].is_a?(Array)
    end
  end

  test 'fetch calls both fetchers at offset 0 with configured per_source' do
    q = { q: 'test' }

    calls = []
    fetcher = lambda do |offset:, per_page:, query: nil|
      calls << [offset, per_page]
      { results: [], hits: 0, errors: nil, show_continuation: false }
    end

    svc = MergedSearchService.new(enhanced_query: { q: 'test' }, active_tab: 'all',
                                  primo_fetcher: fetcher, timdex_fetcher: fetcher)
    ClimateControl.modify(ALL_TAB_RESULTS_PER_SOURCE: '25') { svc.fetch }

    assert_equal 2, calls.length
    calls.each do |offset, per_page|
      assert_equal 0, offset
      assert_equal 25, per_page
    end
  end

  test 'fetch returns merged results from both sources' do
    primo_fetcher = fake_fetcher(results: [{ title: 'P1', score: 0.9, api: 'primo', identifier: 'p1' }], hits: 1)
    timdex_fetcher = fake_fetcher(results: [{ title: 'T1', score: 0.8, api: 'timdex', identifier: 't1' }], hits: 1)

    svc = MergedSearchService.new(enhanced_query: { q: 'test' }, active_tab: 'all',
                                  primo_fetcher: primo_fetcher, timdex_fetcher: timdex_fetcher)
    result = svc.fetch

    assert_equal 2, result[:results].length
    titles = result[:results].map { |r| r[:title] }
    assert_includes titles, 'P1'
    assert_includes titles, 'T1'
  end

  test 'fetch appends only the new stable slice on load more' do
    primo_calls = []
    timdex_calls = []
    primo_fetcher = lambda do |offset:, per_page:, query: nil|
      primo_calls << offset
      results = [
        { title: 'P1', score: 0.9, api: 'primo', identifier: 'p1' },
        { title: 'P2', score: 0.8, api: 'primo', identifier: 'p2' },
        { title: 'P3', score: 0.7, api: 'primo', identifier: 'p3' },
        { title: 'P4', score: 0.6, api: 'primo', identifier: 'p4' }
      ].slice(offset, per_page) || []
      { results: results, hits: 4, errors: nil, show_continuation: false }
    end
    timdex_fetcher = lambda do |offset:, per_page:, query: nil|
      timdex_calls << offset
      results = [
        { title: 'T1', score: 0.95, api: 'timdex', identifier: 't1' },
        { title: 'T2', score: 0.85, api: 'timdex', identifier: 't2' },
        { title: 'T3', score: 0.75, api: 'timdex', identifier: 't3' },
        { title: 'T4', score: 0.65, api: 'timdex', identifier: 't4' }
      ].slice(offset, per_page) || []
      { results: results, hits: 4, errors: nil }
    end

    svc = MergedSearchService.new(enhanced_query: { q: 'test' }, active_tab: 'all',
                                  primo_fetcher: primo_fetcher, timdex_fetcher: timdex_fetcher)

    first = svc.fetch(display_count: 2, stable_count: 0, per_source: 1)
    second = svc.fetch(display_count: 4, stable_count: 2, per_source: 1)

    assert_equal(first[:results].map { |result| result[:identifier] },
                 second[:results].first(2).map { |result| result[:identifier] })
    assert_equal(second[:results].last(2).map { |result| result[:identifier] },
                 second[:append_results].map { |result| result[:identifier] })
    assert_equal [0, 1], primo_calls
    assert_equal [0, 1], timdex_calls
  end

  test 'fetch stops when duplicate source chunks do not grow the ordered result set' do
    calls = []
    fetcher = lambda do |offset:, per_page:, query: nil|
      calls << offset
      { results: [{ title: 'Same', score: 1.0, api: 'primo', identifier: 'same' }], hits: 100, errors: nil }
    end

    svc = MergedSearchService.new(enhanced_query: { q: 'test' }, active_tab: 'all',
                                  primo_fetcher: fetcher, timdex_fetcher: fake_fetcher)
    result = svc.fetch(display_count: 5, stable_count: 0, per_source: 1)

    assert_equal 1, result[:results].length
    assert_operator calls.length, :<=, 2
  end

  test 'fetch defaults to 50 results per source when env var is not set' do
    per_page_seen = []
    fetcher = lambda do |offset:, per_page:, query: nil|
      per_page_seen << per_page
      { results: [], hits: 0, errors: nil }
    end

    svc = MergedSearchService.new(enhanced_query: { q: 'test' }, active_tab: 'all',
                                  primo_fetcher: fetcher, timdex_fetcher: fetcher)
    ClimateControl.modify(ALL_TAB_RESULTS_PER_SOURCE: nil) { svc.fetch }

    assert_equal [50, 50], per_page_seen
  end

  test 'configured_scorer returns Zipper by default' do
    svc = MergedSearchService.new(enhanced_query: { q: 'test' }, active_tab: 'all',
                                  primo_fetcher: fake_fetcher, timdex_fetcher: fake_fetcher)
    ClimateControl.modify(ALL_TAB_SCORER: nil) do
      assert_instance_of Reranker::ZipperMergeScorer, svc.send(:configured_scorer)
    end
  end

  test 'configured_scorer maps ALL_TAB_SCORER env var to correct scorer class' do
    svc = MergedSearchService.new(enhanced_query: { q: 'test' }, active_tab: 'all',
                                  primo_fetcher: fake_fetcher, timdex_fetcher: fake_fetcher)

    {
      'zscore' => Reranker::ZscoreScorer,
      'zipper' => Reranker::ZipperMergeScorer,
      'simple' => Reranker::SimpleScorer,
      'random' => Reranker::RandomScorer
    }.each do |scorer_name, scorer_class|
      ClimateControl.modify(ALL_TAB_SCORER: scorer_name) do
        assert_instance_of scorer_class, svc.send(:configured_scorer),
                           "Expected #{scorer_class} for ALL_TAB_SCORER=#{scorer_name}"
      end
    end
  end

  test 'fetch combines errors from both sources' do
    primo_fetcher = fake_fetcher(errors: [{ 'message' => 'Primo error' }])
    timdex_fetcher = fake_fetcher(errors: [{ 'message' => 'TIMDEX error' }])

    svc = MergedSearchService.new(enhanced_query: { q: 'test' }, active_tab: 'all',
                                  primo_fetcher: primo_fetcher, timdex_fetcher: timdex_fetcher)
    result = svc.fetch

    assert_equal 2, result[:errors].length
  end

  test 'fetch returns nil errors when both sources have no errors' do
    svc = MergedSearchService.new(enhanced_query: { q: 'test' }, active_tab: 'all',
                                  primo_fetcher: fake_fetcher, timdex_fetcher: fake_fetcher)
    assert_nil svc.fetch[:errors]
  end

  test 'fetch supports legacy page mode' do
    primo_fetcher = fake_fetcher(results: [{ title: 'P1', score: 0.9, api: 'primo', identifier: 'p1' }], hits: 1)
    timdex_fetcher = fake_fetcher(results: [{ title: 'T1', score: 0.8, api: 'timdex', identifier: 't1' }], hits: 1)

    svc = MergedSearchService.new(enhanced_query: { q: 'test' }, active_tab: 'all',
                                  primo_fetcher: primo_fetcher, timdex_fetcher: timdex_fetcher)
    result = svc.fetch(page: 1, per_page: 20)

    assert_equal 2, result[:results].length
    assert result[:pagination].present?
    assert_nil result[:load_more]
  end

  test 'combine_errors merges arrays or returns nil' do
    svc = MergedSearchService.new(enhanced_query: { q: 'foo' }, active_tab: 'all',
                                  primo_fetcher: fake_fetcher, timdex_fetcher: fake_fetcher)
    assert_nil svc.send(:combine_errors, nil, [])
    merged = svc.send(:combine_errors, [{ 'message' => 'a' }], [{ 'message' => 'b' }])
    assert_equal 2, merged.length
  end

  # The tests that asserted behavior of the removed default fetchers were
  # intentionally removed; the service now requires injected fetchers so
  # per-backend behavior should be tested in their respective unit tests.

  test 'fetch handles unbalanced source responses and returns all available records' do
    primo_all = (1..3).map { |i| { title: "P#{i}", score: 1.0 - (i * 0.01), api: 'primo', identifier: "p#{i}" } }
    timdex_all = (1..5).map { |i| { title: "T#{i}", score: 1.0 - (i * 0.01), api: 'timdex', identifier: "t#{i}" } }

    primo_fetcher = lambda do |offset:, per_page:, query: nil|
      { results: primo_all.slice(offset, per_page) || [], hits: primo_all.length, errors: nil,
        show_continuation: false }
    end
    timdex_fetcher = lambda do |offset:, per_page:, query: nil|
      { results: timdex_all.slice(offset, per_page) || [], hits: timdex_all.length, errors: nil }
    end

    svc = MergedSearchService.new(enhanced_query: { q: 'test' }, active_tab: 'all',
                                  primo_fetcher: primo_fetcher, timdex_fetcher: timdex_fetcher)
    result = svc.fetch(display_count: 8, stable_count: 0, per_source: 2)

    assert_equal 8, result[:results].length
    ids = result[:results].map { |record| record[:identifier] }.sort
    assert_equal %w[p1 p2 p3 t1 t2 t3 t4 t5], ids
  end
end
