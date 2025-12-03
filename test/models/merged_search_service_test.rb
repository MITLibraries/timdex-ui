require 'test_helper'
require 'ostruct'

class MergedSearchServiceTest < ActiveSupport::TestCase
  test 'page 1 writes totals to cache' do
    mem_cache = ActiveSupport::Cache::MemoryStore.new
    query = { q: 'test' }

    primo_fetcher = lambda do |offset:, per_page:, query:|
      { results: ['foo'], hits: 42, errors: nil, show_continuation: false }
    end

    timdex_fetcher = lambda do |offset:, per_page:, query:|
      { results: ['bar'], hits: 37, errors: nil }
    end

    service = MergedSearchService.new(enhanced_query: query, active_tab: 'all', cache: mem_cache,
                                      primo_fetcher: primo_fetcher, timdex_fetcher: timdex_fetcher)

    res = service.fetch(page: 1, per_page: 20)
    assert_equal 2, res[:results].length

    # Verify cache written
    key = service.send(:totals_cache_key)
    cached = mem_cache.read(key)
    refute_nil cached
    assert_equal 42, cached[:primo]
    assert_equal 37, cached[:timdex]
  end

  test 'deeper page reads cached totals and avoids summary calls' do
    mem_cache = ActiveSupport::Cache::MemoryStore.new
    query = { q: 'test' }

    service = MergedSearchService.new(enhanced_query: query, active_tab: 'all', cache: mem_cache)

    # populate cache so service uses it instead of summary calls
    mem_cache.write(service.send(:totals_cache_key), { primo: 50, timdex: 50 })

    # fetchers that would raise if a summary call (per_page == 1) is attempted
    primo_fetcher = lambda do |offset:, per_page:, query:|
      raise 'Summary call made' if per_page == 1

      { results: ['foo'], hits: 50, errors: nil, show_continuation: false }
    end

    timdex_fetcher = lambda do |offset:, per_page:, query:|
      raise 'Summary call made' if per_page == 1

      { results: ['bar'], hits: 50, errors: nil }
    end

    service = MergedSearchService.new(enhanced_query: query, active_tab: 'all', cache: mem_cache,
                                      primo_fetcher: primo_fetcher, timdex_fetcher: timdex_fetcher)

    # Should not raise
    assert_nothing_raised do
      res = service.fetch(page: 2, per_page: 20)
      assert res[:results].is_a?(Array)
    end
  end

  test 'falls back to summary and writes cache when totals are missing' do
    mem_cache = ActiveSupport::Cache::MemoryStore.new
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

    svc = MergedSearchService.new(enhanced_query: q, active_tab: 'all', cache: mem_cache, primo_fetcher: primo_fetcher,
                                  timdex_fetcher: timdex_fetcher)

    res = svc.fetch(page: 2, per_page: 20)

    # summary calls should have been made with per_page == 1
    assert_includes calls, [:primo, 0, 1]
    assert_includes calls, [:timdex, 0, 1]

    # totals cached
    key = svc.send(:totals_cache_key)
    totals = mem_cache.read(key)
    refute_nil totals
    assert_equal 7, totals[:primo]
    assert_equal 3, totals[:timdex]

    assert res[:results].is_a?(Array)
  end

  test 'default_primo_fetch returns continuation when offset exceeds max' do
    svc = MergedSearchService.new(enhanced_query: { q: 'foo' }, active_tab: 'all', cache: ActiveSupport::Cache::MemoryStore.new)
    res = svc.send(:default_primo_fetch, offset: Analyzer::PRIMO_MAX_OFFSET, per_page: 20, query: { q: 'foo' })
    assert_equal true, res[:show_continuation]
    assert_equal 0, res[:hits]
  end

  test 'default_primo_fetch handles exceptions gracefully' do
    svc = MergedSearchService.new(enhanced_query: { q: 'foo' }, active_tab: 'all', cache: ActiveSupport::Cache::MemoryStore.new)
    PrimoSearch.expects(:new).raises(StandardError.new('boom'))
    res = svc.send(:default_primo_fetch, offset: 0, per_page: 10, query: { q: 'foo' })
    assert_equal 0, res[:hits]
    assert res[:errors].is_a?(Array)
  end

  test 'default_timdex_fetch handles client errors gracefully' do
    svc = MergedSearchService.new(enhanced_query: { q: 'foo' }, active_tab: 'all', cache: ActiveSupport::Cache::MemoryStore.new)
    TimdexBase::Client.expects(:query).raises(StandardError.new('boom'))
    res = svc.send(:default_timdex_fetch, offset: 0, per_page: 10, query: { q: 'foo' })
    assert_equal 0, res[:hits]
    assert res[:errors].is_a?(Array)
  end

  test 'fetch_all_tab_page_chunks handles zero-count branches' do
    mem = ActiveSupport::Cache::MemoryStore.new
    called = []
    primo_fetcher = lambda { |offset:, per_page:, query:|
      called << [:primo, offset, per_page]
      { results: ['P'], hits: 5, errors: nil, show_continuation: false }
    }
    timdex_fetcher = lambda { |offset:, per_page:, query:|
      called << [:timdex, offset, per_page]
      { results: [], hits: 0, errors: nil }
    }

    svc = MergedSearchService.new(enhanced_query: { q: 'foo' }, active_tab: 'all', cache: mem,
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
    svc = MergedSearchService.new(enhanced_query: { q: 'foo' }, active_tab: 'all', cache: ActiveSupport::Cache::MemoryStore.new)
    assert_nil svc.send(:combine_errors, nil, [])
    merged = svc.send(:combine_errors, [{ 'message' => 'a' }], [{ 'message' => 'b' }])
    assert_equal 2, merged.length
  end

  test 'default_primo_fetch returns normalized results on success' do
    svc = MergedSearchService.new(enhanced_query: { q: 'foo' }, active_tab: 'all', cache: ActiveSupport::Cache::MemoryStore.new)
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
    svc = MergedSearchService.new(enhanced_query: { q: 'foo' }, active_tab: 'all', cache: ActiveSupport::Cache::MemoryStore.new)
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
end
