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

    service = MergedSearchService.new(enhanced_query: query, active_tab: 'all',
                                      primo_fetcher: fake_fetcher, timdex_fetcher: fake_fetcher)

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
    svc = MergedSearchService.new(enhanced_query: { q: 'foo' }, active_tab: 'all', primo_fetcher: fake_fetcher,
                                  timdex_fetcher: fake_fetcher)
    assert_nil svc.send(:combine_errors, nil, [])
    merged = svc.send(:combine_errors, [{ 'message' => 'a' }], [{ 'message' => 'b' }])
    assert_equal 2, merged.length
  end

  # The tests that asserted behavior of the removed default fetchers were
  # intentionally removed; the service now requires injected fetchers so
  # per-backend behavior should be tested in their respective unit tests.

  test 'detect_incomplete_results identifies which sources timed out' do
    svc = MergedSearchService.new(enhanced_query: { q: 'foo' }, active_tab: 'all', primo_fetcher: fake_fetcher,
                                  timdex_fetcher: fake_fetcher)

    # Test 1: No timeouts
    primo_data = { results: ['p1'], hits: 10, errors: nil }
    timdex_data = { results: ['t1'], hits: 20, errors: nil }
    result = svc.send(:detect_incomplete_results, primo_data, timdex_data)
    assert_nil result

    # Test 2: Primo times out
    primo_data = { results: [], hits: 0, errors: nil, timed_out: true }
    timdex_data = { results: ['t1'], hits: 20, errors: nil }
    result = svc.send(:detect_incomplete_results, primo_data, timdex_data)
    assert_equal({ sources: ['Primo'] }, result)

    # Test 3: TIMDEX times out
    primo_data = { results: ['p1'], hits: 10, errors: nil }
    timdex_data = { results: [], hits: 0, errors: nil, timed_out: true }
    result = svc.send(:detect_incomplete_results, primo_data, timdex_data)
    assert_equal({ sources: ['TIMDEX'] }, result)

    # Test 4: Both time out
    primo_data = { results: [], hits: 0, errors: nil, timed_out: true }
    timdex_data = { results: [], hits: 0, errors: nil, timed_out: true }
    result = svc.send(:detect_incomplete_results, primo_data, timdex_data)
    assert_equal({ sources: %w[Primo TIMDEX] }, result)

    # Test 5: timed_out flag takes precedence (timeout doesn't go in errors field)
    primo_data = { results: [], hits: 0, errors: nil, timed_out: true }
    timdex_data = { results: ['t1'], hits: 20, errors: 'Some other error' }
    result = svc.send(:detect_incomplete_results, primo_data, timdex_data)
    assert_equal({ sources: ['Primo'] }, result)
  end

  test 'assemble_all_tab_result includes incomplete_results flag for timeouts' do
    query = { q: 'test' }

    # Fetcher that returns timed_out flag
    primo_fetcher = lambda do |offset:, per_page:, query:|
      { results: [], hits: 0, errors: nil, timed_out: true, show_continuation: false }
    end

    timdex_fetcher = lambda do |offset:, per_page:, query:|
      { results: ['bar'], hits: 37, errors: nil }
    end

    svc = MergedSearchService.new(enhanced_query: query, active_tab: 'all',
                                  primo_fetcher: primo_fetcher, timdex_fetcher: timdex_fetcher)

    res = svc.fetch(page: 1, per_page: 20)

    # Results should include TIMDEX data even though Primo timed out
    assert res[:results].present?
    assert_equal(['bar'], res[:results])

    # Incomplete results flag should be set
    assert res[:incomplete_results].present?
    assert_equal(['Primo'], res[:incomplete_results][:sources])

    # Overall errors should be nil (timeout doesn't block partial results)
    assert_nil res[:errors]
  end
end
