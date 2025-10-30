require 'test_helper'

class AnalyzerTest < ActiveSupport::TestCase
  test 'analyzer pagination does not include previous page value on first page of results' do
    hit_count = 95
    Analyzer.any_instance.stubs(:hits).returns(hit_count)
    mocking_hits_so_this_is_empty = {}

    eq = {
      q: 'data',
      page: 1
    }

    pagination = Analyzer.new(eq, mocking_hits_so_this_is_empty, :timdex).pagination

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
    Analyzer.any_instance.stubs(:hits).returns(hit_count)
    mocking_hits_so_this_is_empty = {}

    eq = {
      q: 'data',
      page: 2
    }

    pagination = Analyzer.new(eq, mocking_hits_so_this_is_empty, :timdex).pagination

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
    Analyzer.any_instance.stubs(:hits).returns(hit_count)

    mocking_hits_so_this_is_empty = {}
    eq = {
      q: 'data',
      page: 5
    }

    pagination = Analyzer.new(eq, mocking_hits_so_this_is_empty, :timdex).pagination

    assert pagination.key?(:hits)
    assert pagination.key?(:start)
    assert pagination.key?(:end)
    assert pagination.key?(:prev)

    refute pagination[:next]

    assert_equal 81, pagination[:start]
    assert_equal hit_count, pagination[:end]
  end

  test 'analyzer works with primo response format' do
    primo_response = {
      'info' => {
        'total' => 45
      }
    }

    eq = {
      q: 'data',
      page: 1
    }

    pagination = Analyzer.new(eq, primo_response, :primo).pagination

    assert_equal 45, pagination[:hits]
    assert_equal 1, pagination[:start]
    assert_equal 20, pagination[:end]
    assert_equal 2, pagination[:next]
    refute pagination.key?(:prev)
  end

  test 'analyzer works with timdex response format' do
    timdex_response = {
      data: {
        'search' => {
          'hits' => 75
        }
      }
    }

    eq = {
      q: 'data',
      page: 2
    }

    pagination = Analyzer.new(eq, timdex_response, :timdex).pagination

    assert_equal 75, pagination[:hits]
    assert_equal 21, pagination[:start]
    assert_equal 40, pagination[:end]
    assert_equal 3, pagination[:next]
    assert_equal 1, pagination[:prev]
  end

  test 'analyzer handles missing primo total gracefully' do
    primo_response = {
      'info' => {}
    }

    eq = {
      q: 'data',
      page: 1
    }

    pagination = Analyzer.new(eq, primo_response, :primo).pagination

    assert_equal 0, pagination[:hits]
    assert_equal 1, pagination[:start]
    assert_equal 0, pagination[:end]
    refute pagination.key?(:next)
    refute pagination.key?(:prev)
  end

  test 'analyzer extracts large hit counts from primo responses' do
    primo_response = {
      'info' => {
        'total' => 68_644_281 # Real-world example
      }
    }

    eq = {
      q: 'data',
      page: 1
    }

    pagination = Analyzer.new(eq, primo_response, :primo).pagination

    # Should show the actual hit count from the API response
    assert_equal 68_644_281, pagination[:hits]
    assert_equal 1, pagination[:start]
    assert_equal 20, pagination[:end]
    assert_equal 2, pagination[:next]
    refute pagination.key?(:prev)
  end

  test 'analyzer extracts large hit counts from timdex responses' do
    timdex_response = {
      data: {
        'search' => {
          'hits' => 68_644_281 # Same large number as Primo example
        }
      }
    }

    eq = {
      q: 'data',
      page: 1
    }

    pagination = Analyzer.new(eq, timdex_response, :timdex).pagination

    # Should show the actual hit count from the API response
    assert_equal 68_644_281, pagination[:hits]
    assert_equal 1, pagination[:start]
    assert_equal 20, pagination[:end]
    assert_equal 2, pagination[:next]
    refute pagination.key?(:prev)
  end

  test 'analyzer handles unknown source types gracefully' do
    response = { 'some' => 'data' }

    eq = {
      q: 'data',
      page: 1
    }

    pagination = Analyzer.new(eq, response, :unknown_source).pagination

    # Should default to 0 hits for unknown source types
    assert_equal 0, pagination[:hits]
    assert_equal 1, pagination[:start]
    assert_equal 0, pagination[:end]
    refute pagination.key?(:next)
    refute pagination.key?(:prev)
  end
end
