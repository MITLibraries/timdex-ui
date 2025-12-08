require 'test_helper'
require 'ostruct'

class MergedSearchServiceTest < ActiveSupport::TestCase
  test 'page 1 writes totals to cache' do
    query = { q: 'test' }

    primo_fetcher = lambda do |offset:, per_page:, query:|
      { results: ['foo'], hits: 42, errors: nil, show_continuation: false }
    end

    timdex_fetcher = lambda do |offset:, per_page:, query:|
      { results: ['bar'], hits: 37, errors: nil }
    end

    service = MergedSearchService.new(enhanced_query: query, active_tab: 'all',
                                      primo_fetcher: primo_fetcher, timdex_fetcher: timdex_fetcher)

    res = service.fetch(page: 1, per_page: 20)
    assert_equal 2, res[:results].length

    # Verify cache written
    key = service.send(:totals_cache_key)
    cached = Rails.cache.read(key)
    refute_nil cached
    assert_equal 42, cached[:primo]
    assert_equal 37, cached[:timdex]
  end

  test 'deeper page reads cached totals and avoids summary calls' do
    query = { q: 'test' }

    service = MergedSearchService.new(enhanced_query: query, active_tab: 'all')

    # populate cache so service uses it instead of summary calls
    Rails.cache.write(service.send(:totals_cache_key), { primo: 50, timdex: 50 })

    # fetchers that would raise if a summary call (per_page == 1) is attempted
    primo_fetcher = lambda do |offset:, per_page:, query:|
      raise 'Summary call made' if per_page == 1

      { results: ['foo'], hits: 50, errors: nil, show_continuation: false }
    end

    timdex_fetcher = lambda do |offset:, per_page:, query:|
      raise 'Summary call made' if per_page == 1

      { results: ['bar'], hits: 50, errors: nil }
    end

    service = MergedSearchService.new(enhanced_query: query, active_tab: 'all',
                                      primo_fetcher: primo_fetcher, timdex_fetcher: timdex_fetcher)

    # Should not raise
    assert_nothing_raised do
      res = service.fetch(page: 2, per_page: 20)
      assert res[:results].is_a?(Array)
    end
  end

  test 'falls back to summary and writes cache when totals are missing' do
    q = { q: 'test' }

    calls = []
    primo_fetcher = lambda do |offset:, per_page:, query:|
      calls << [:primo, offset, per_page]
      if per_page == 1
        { results: [], hits: 7, errors: nil, show_continuation: false }
      else
        { results: ['foo'], hits: 7, errors: nil, show_continuation: false }
      end
    end

    timdex_fetcher = lambda do |offset:, per_page:, query:|
      calls << [:timdex, offset, per_page]
      if per_page == 1
        { results: [], hits: 3, errors: nil }
      else
        { results: ['bar'], hits: 3, errors: nil }
      end
    end

    svc = MergedSearchService.new(enhanced_query: q, active_tab: 'all', primo_fetcher: primo_fetcher,
                                  timdex_fetcher: timdex_fetcher)

    res = svc.fetch(page: 2, per_page: 20)

    # summary calls should have been made with per_page == 1
    assert_includes calls, [:primo, 0, 1]
    assert_includes calls, [:timdex, 0, 1]

    # totals cached
    key = svc.send(:totals_cache_key)
    totals = Rails.cache.read(key)
    refute_nil totals
    assert_equal 7, totals[:primo]
    assert_equal 3, totals[:timdex]

    assert res[:results].is_a?(Array)
  end

  test 'default_primo_fetch returns continuation when offset exceeds max' do
    svc = MergedSearchService.new(enhanced_query: { q: 'foo' }, active_tab: 'all')
    res = svc.send(:default_primo_fetch, offset: Analyzer::PRIMO_MAX_OFFSET, per_page: 20, query: { q: 'foo' })
    assert_equal true, res[:show_continuation]
    assert_equal 0, res[:hits]
  end

  test 'default_primo_fetch handles exceptions gracefully' do
    svc = MergedSearchService.new(enhanced_query: { q: 'foo' }, active_tab: 'all')
    PrimoSearch.expects(:new).raises(StandardError.new('boom'))
    res = svc.send(:default_primo_fetch, offset: 0, per_page: 10, query: { q: 'foo' })
    assert_equal 0, res[:hits]
    assert res[:errors].is_a?(Array)
  end

  test 'default_timdex_fetch handles client errors gracefully' do
    svc = MergedSearchService.new(enhanced_query: { q: 'foo' }, active_tab: 'all')
    TimdexBase::Client.expects(:query).raises(StandardError.new('boom'))
    res = svc.send(:default_timdex_fetch, offset: 0, per_page: 10, query: { q: 'foo' })
    assert_equal 0, res[:hits]
    assert res[:errors].is_a?(Array)
  end

  test 'fetch_all_tab_page_chunks handles zero-count branches' do
    called = []
    primo_fetcher = lambda { |offset:, per_page:, query:|
      called << [:primo, offset, per_page]
      { results: ['P'], hits: 5, errors: nil, show_continuation: false }
    }
    timdex_fetcher = lambda { |offset:, per_page:, query:|
      called << [:timdex, offset, per_page]
      { results: [], hits: 0, errors: nil }
    }

    svc = MergedSearchService.new(enhanced_query: { q: 'foo' }, active_tab: 'all',
                                  primo_fetcher: primo_fetcher, timdex_fetcher: timdex_fetcher)

    paginator = OpenStruct.new(
      merge_plan: %i[primo primo],
      api_offsets: [10, 0],
      primo_total: 5,
      timdex_total: 0
    )

    primo_data, timdex_data = svc.send(:fetch_all_tab_page_chunks, paginator)
    assert primo_data[:results].is_a?(Array)
    assert timdex_data[:results].is_a?(Array)
    assert_equal 0, timdex_data[:hits]
  end

  test 'combine_errors merges arrays or returns nil' do
    svc = MergedSearchService.new(enhanced_query: { q: 'foo' }, active_tab: 'all')
    assert_nil svc.send(:combine_errors, nil, [])
    merged = svc.send(:combine_errors, [{ 'message' => 'a' }], [{ 'message' => 'b' }])
    assert_equal 2, merged.length
  end

  test 'default_primo_fetch returns normalized results on success' do
    svc = MergedSearchService.new(enhanced_query: { q: 'foo' }, active_tab: 'all')
    mock_primo = mock('primo_search')
    mock_primo.expects(:search).returns({ 'info' => { 'total' => 12 }, 'docs' => [] })
    PrimoSearch.expects(:new).returns(mock_primo)

    mock_normalizer = mock('normalizer')
    mock_normalizer.expects(:normalize).returns(['normalized'])
    NormalizePrimoResults.expects(:new).returns(mock_normalizer)

    mock_analyzer = mock('analyzer')
    mock_analyzer.expects(:pagination).returns({ page: 1 })
    Analyzer.expects(:new).returns(mock_analyzer)

    res = svc.send(:default_primo_fetch, offset: 0, per_page: 10, query: { q: 'foo' })
    assert_equal 12, res[:hits]
    assert_equal ['normalized'], res[:results]
    assert_equal({ page: 1 }, res[:pagination])
  end

  test 'default_timdex_fetch returns normalized results on success' do
    svc = MergedSearchService.new(enhanced_query: { q: 'foo' }, active_tab: 'all')
    fake_resp = OpenStruct.new(data: OpenStruct.new(to_h: { 'search' => { 'hits' => 5,
                                                                          'records' => [{ 'id' => 1 }] } }))
    TimdexBase::Client.stubs(:query).returns(fake_resp)

    mock_normalizer = mock('normalizer')
    mock_normalizer.expects(:normalize).returns(['t_normalized'])
    NormalizeTimdexResults.expects(:new).returns(mock_normalizer)

    mock_analyzer = mock('analyzer')
    mock_analyzer.expects(:pagination).returns({ page: 1 })
    Analyzer.expects(:new).returns(mock_analyzer)

    res = svc.send(:default_timdex_fetch, offset: 0, per_page: 10, query: { q: 'foo' })
    assert_equal 5, res[:hits]
    assert_equal ['t_normalized'], res[:results]
    assert_equal({ page: 1 }, res[:pagination])
  end

  test 'merge_results handles unbalanced API responses correctly' do
    # Test case 1: Primo has fewer results than TIMDEX
    paginator = MergedSearchPaginator.new(primo_total: 3, timdex_total: 5, current_page: 1, per_page: 8)
    primo_results = %w[P1 P2 P3]
    timdex_results = %w[T1 T2 T3 T4 T5]
    svc = MergedSearchService.new(enhanced_query: { q: 'test' }, active_tab: 'all')
    merged = svc.send(:merge_results, paginator, primo_results, timdex_results)
    expected = %w[P1 T1 P2 T2 P3 T3 T4 T5]
    assert_equal expected, merged

    # Test case 2: TIMDEX has fewer results than Primo
    paginator = MergedSearchPaginator.new(primo_total: 5, timdex_total: 3, current_page: 1, per_page: 8)
    primo_results = %w[P1 P2 P3 P4 P5]
    timdex_results = %w[T1 T2 T3]
    svc = MergedSearchService.new(enhanced_query: { q: 'test' }, active_tab: 'all')
    merged = svc.send(:merge_results, paginator, primo_results, timdex_results)
    expected = %w[P1 T1 P2 T2 P3 T3 P4 P5]
    assert_equal expected, merged

    # Test case 3: Results exceed per_page limit (default 20)
    paginator = MergedSearchPaginator.new(primo_total: 15, timdex_total: 15, current_page: 1, per_page: 20)
    primo_results = (1..15).map { |i| "P#{i}" }
    timdex_results = (1..15).map { |i| "T#{i}" }
    svc = MergedSearchService.new(enhanced_query: { q: 'test' }, active_tab: 'all')
    merged = svc.send(:merge_results, paginator, primo_results, timdex_results)
    assert_equal 20, merged.length
    assert_equal 'P1', merged[0]
    assert_equal 'T1', merged[1]
    assert_equal 'P2', merged[2]
    assert_equal 'T2', merged[3]

    # Test case 4: One array is empty
    paginator = MergedSearchPaginator.new(primo_total: 0, timdex_total: 3, current_page: 1, per_page: 3)
    primo_results = []
    timdex_results = %w[T1 T2 T3]
    svc = MergedSearchService.new(enhanced_query: { q: 'test' }, active_tab: 'all')
    merged = svc.send(:merge_results, paginator, primo_results, timdex_results)
    assert_equal %w[T1 T2 T3], merged

    # Test case 5: more than 10 results from a single source can display when appropriate
    paginator = MergedSearchPaginator.new(primo_total: 7, timdex_total: 11, current_page: 1, per_page: 18)
    primo_results = (1..7).map { |i| "P#{i}" }
    timdex_results = (1..11).map { |i| "T#{i}" }
    svc = MergedSearchService.new(enhanced_query: { q: 'test' }, active_tab: 'all')
    merged = svc.send(:merge_results, paginator, primo_results, timdex_results)
    expected = %w[P1 T1 P2 T2 P3 T3 P4 T4 P5 T5 P6 T6 P7 T7 T8 T9 T10 T11]
    assert_equal expected, merged
  end
end
