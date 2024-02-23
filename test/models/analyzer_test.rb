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
    query = { 'q' => 'data', 'from' => '0' }

    pagination = Analyzer.new(eq, mocking_hits_so_this_is_empty).pagination

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
    query = { 'q' => 'data', 'from' => '20' }

    pagination = Analyzer.new(eq, mocking_hits_so_this_is_empty).pagination

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

    pagination = Analyzer.new(eq, mocking_hits_so_this_is_empty).pagination

    assert pagination.key?(:hits)
    assert pagination.key?(:start)
    assert pagination.key?(:end)
    assert pagination.key?(:prev)

    refute pagination[:next]

    assert_equal 81, pagination[:start]
    assert_equal hit_count, pagination[:end]
  end
end
