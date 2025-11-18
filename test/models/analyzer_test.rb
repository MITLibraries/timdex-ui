require 'test_helper'

class AnalyzerTest < ActiveSupport::TestCase
  test 'analyzer pagination does not include previous page value on first page of results' do
    hit_count = 95
    eq = {
      q: 'data',
      page: 1
    }

    pagination = Analyzer.new(eq, hit_count, :timdex).pagination

    assert pagination.key?(:hits)
    assert pagination.key?(:start)
    assert pagination.key?(:end)
    assert pagination.key?(:next)

    refute pagination.key?(:prev)

    assert_equal 1, pagination[:start]
    assert_equal 20, pagination[:end]
  end

  test 'analyzer pagination includes all values when not on first or last page of results' do
    hit_count = 95
    eq = {
      q: 'data',
      page: 2
    }

    pagination = Analyzer.new(eq, hit_count, :timdex).pagination

    assert pagination.key?(:hits)
    assert pagination.key?(:start)
    assert pagination.key?(:end)
    assert pagination.key?(:next)
    assert pagination.key?(:prev)

    assert_equal 21, pagination[:start]
    assert_equal 40, pagination[:end]
  end

  test 'analyzer pagination does not include last page value on last page of results' do
    hit_count = 95

    eq = {
      q: 'data',
      page: 5
    }

    pagination = Analyzer.new(eq, hit_count, :timdex).pagination

    assert pagination.key?(:hits)
    assert pagination.key?(:start)
    assert pagination.key?(:end)
    assert pagination.key?(:prev)

    refute pagination[:next]

    assert_equal 81, pagination[:start]
    assert_equal hit_count, pagination[:end]
  end

  test 'analyzer works with primo response format' do
    eq = {
      q: 'data',
      page: 1
    }

    pagination = Analyzer.new(eq, 45, :primo).pagination

    assert_equal 45, pagination[:hits]
    assert_equal 1, pagination[:start]
    assert_equal 20, pagination[:end]
    assert_equal 2, pagination[:next]
    refute pagination.key?(:prev)
  end

  test 'analyzer works with timdex response format' do
    eq = {
      q: 'data',
      page: 2
    }

    pagination = Analyzer.new(eq, 75, :timdex).pagination

    assert_equal 75, pagination[:hits]
    assert_equal 21, pagination[:start]
    assert_equal 40, pagination[:end]
    assert_equal 3, pagination[:next]
    assert_equal 1, pagination[:prev]
  end

  test 'analyzer handles missing primo total gracefully' do
    eq = {
      q: 'data',
      page: 1
    }

    pagination = Analyzer.new(eq, 0, :primo).pagination

    assert_equal 0, pagination[:hits]
    assert_equal 1, pagination[:start]
    assert_equal 0, pagination[:end]
    refute pagination.key?(:next)
    refute pagination.key?(:prev)
  end

  test 'analyzer extracts large hit counts from primo responses' do
    eq = {
      q: 'data',
      page: 1
    }

    pagination = Analyzer.new(eq, 68_644_281, :primo).pagination

    # Should show the actual hit count from the API response
    assert_equal 68_644_281, pagination[:hits]
    assert_equal 1, pagination[:start]
    assert_equal 20, pagination[:end]
    assert_equal 2, pagination[:next]
    refute pagination.key?(:prev)
  end

  test 'analyzer extracts large hit counts from timdex responses' do
    eq = {
      q: 'data',
      page: 1
    }

    pagination = Analyzer.new(eq, 68_644_281, :timdex).pagination

    # Should show the actual hit count from the API response
    assert_equal 68_644_281, pagination[:hits]
    assert_equal 1, pagination[:start]
    assert_equal 20, pagination[:end]
    assert_equal 2, pagination[:next]
    refute pagination.key?(:prev)
  end

  test 'analyzer handles unknown source types gracefully' do
    eq = {
      q: 'data',
      page: 1
    }

    pagination = Analyzer.new(eq, 0, :unknown_source).pagination

    # Should default to 0 hits for unknown source types
    assert_equal 0, pagination[:hits]
    assert_equal 1, pagination[:start]
    assert_equal 0, pagination[:end]
    refute pagination.key?(:next)
    refute pagination.key?(:prev)
  end

  test 'analyzer combines hit counts for all tab with both API responses' do
    eq = {
      q: 'data',
      page: 1
    }

    pagination = Analyzer.new(eq, 250, :all, 150).pagination

    # Should combine hits from both APIs: 150 + 250 = 400
    assert_equal 400, pagination[:hits]
    assert_equal 1, pagination[:start]
    assert_equal 20, pagination[:end]
    assert_equal 2, pagination[:next]
    refute pagination.key?(:prev)
  end

  test 'analyzer handles nil responses for all tab' do
    eq = {
      q: 'data',
      page: 1
    }

    pagination = Analyzer.new(eq, nil, :all, nil).pagination

    assert_equal 0, pagination[:hits]
    assert_equal 1, pagination[:start]
    assert_equal 0, pagination[:end]
    refute pagination.key?(:next)
    refute pagination.key?(:prev)
  end

  test 'analyzer calculates pagination correctly for all tab on page 2' do
    eq = {
      q: 'data',
      page: 2
    }

    pagination = Analyzer.new(eq, 500, :all, 300).pagination

    # Should combine hits: 300 + 500 = 800
    # Page 2 should show results 21-40 of 800
    assert_equal 800, pagination[:hits]
    assert_equal 21, pagination[:start]
    assert_equal 40, pagination[:end]
    assert_equal 1, pagination[:prev]
    assert_equal 3, pagination[:next]
  end

  test 'analyzer handles unbalanced API results for all tab' do
    eq = {
      q: 'data',
      page: 1
    }

    pagination = Analyzer.new(eq, 5, :all, 10_000).pagination

    # Should still combine hits and calculate pagination as expected
    assert_equal 10_005, pagination[:hits]
    assert_equal 1, pagination[:start]
    assert_equal 20, pagination[:end]
    assert_equal 2, pagination[:next]
    refute pagination.key?(:prev)
  end

  test 'analyzer handles first API returning zero results for all tab' do
    eq = {
      q: 'data',
      page: 1
    }

    pagination = Analyzer.new(eq, 0, :all, 150).pagination

    assert_equal 150, pagination[:hits]
    assert_equal 1, pagination[:start]
    assert_equal 20, pagination[:end]
    assert_equal 2, pagination[:next]
    refute pagination.key?(:prev)
  end

  test 'analyzer handles second API returning zero results for all tab' do
    eq = {
      q: 'data',
      page: 1
    }

    pagination = Analyzer.new(eq, 150, :all, 0).pagination

    assert_equal 150, pagination[:hits]
    assert_equal 1, pagination[:start]
    assert_equal 20, pagination[:end]
    assert_equal 2, pagination[:next]
    refute pagination.key?(:prev)
  end

  test 'analyzer handles missing second API response for all tab' do
    eq = {
      q: 'data',
      page: 1
    }

    pagination = Analyzer.new(eq, 100, :all).pagination

    assert_equal 100, pagination[:hits]
    assert_equal 1, pagination[:start]
    assert_equal 20, pagination[:end]
    assert_equal 2, pagination[:next]
    refute pagination.key?(:prev)
  end

  test 'analyzer handles both APIs returning zero results for all tab' do
    eq = {
      q: 'data',
      page: 1
    }

    pagination = Analyzer.new(eq, 0, :all, 0).pagination

    assert_equal 0, pagination[:hits]
    assert_equal 1, pagination[:start]
    assert_equal 0, pagination[:end]
    refute pagination.key?(:next)
    refute pagination.key?(:prev)
  end

  test 'analyzer handles very large combined hit counts for all tab' do
    eq = {
      q: 'data',
      page: 500
    }

    pagination = Analyzer.new(eq, 75_000_000, :all, 25_000_000).pagination

    assert_equal 100_000_000, pagination[:hits]
    assert_equal 9981, pagination[:start] # (500-1) * 20 + 1
    assert_equal 10_000, pagination[:end] # 500 * 20
    assert_equal 499, pagination[:prev]
    assert_equal 501, pagination[:next]
  end

  test 'analyzer respects RESULTS_PER_PAGE environment variable' do
    eq = {
      q: 'data',
      page: 2
    }

    pagination = Analyzer.new(eq, 100, :timdex).pagination
    assert_equal 20, pagination[:per_page]
    assert_equal 21, pagination[:start] # (2-1) * 20 + 1
    assert_equal 40, pagination[:end] # 2 * 20

    ClimateControl.modify RESULTS_PER_PAGE: '10' do
      pagination = Analyzer.new(eq, 100, :timdex).pagination
      assert_equal 10, pagination[:per_page]
      assert_equal 11, pagination[:start] # (2-1) * 10 + 1
      assert_equal 20, pagination[:end] # 2 * 10
    end

    ClimateControl.modify RESULTS_PER_PAGE: '50' do
      pagination = Analyzer.new(eq, 200, :timdex).pagination
      assert_equal 50, pagination[:per_page]
      assert_equal 51, pagination[:start] # (2-1) * 50 + 1
      assert_equal 100, pagination[:end] # 2 * 50
    end
  end
end
