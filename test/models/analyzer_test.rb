require 'test_helper'

class AnalyzerTest < ActiveSupport::TestCase
  test 'analyzer pagination does not include previous page value on first page of results' do
    Analyzer.any_instance.stubs(:hits).returns(100)
    mocking_hits_so_this_is_empty = {}

    eq = {
      q: 'data',
      page: 1
    }
    query = { 'q' => 'data', 'from' => '0' }

    pagination = Analyzer.new(eq, mocking_hits_so_this_is_empty).pagination

    assert pagination.key?(:hits)
    assert pagination.key?(:next)
    assert pagination.key?(:page)

    refute pagination.key?(:prev)
  end

  test 'analyzer pagination includes all values when not on first or last page of results' do
    Analyzer.any_instance.stubs(:hits).returns(100)
    mocking_hits_so_this_is_empty = {}

    eq = {
      q: 'data',
      page: 2
    }
    query = { 'q' => 'data', 'from' => '20' }

    pagination = Analyzer.new(eq, mocking_hits_so_this_is_empty).pagination

    assert pagination.key?(:hits)
    assert pagination.key?(:next)
    assert pagination.key?(:prev)
    assert pagination.key?(:page)
  end

  test 'analyzer pagination does not include last page value on last page of results' do
    Analyzer.any_instance.stubs(:hits).returns(100)

    mocking_hits_so_this_is_empty = {}
    eq = {
      q: 'data',
      page: 28
    }

    pagination = Analyzer.new(eq, mocking_hits_so_this_is_empty).pagination

    assert pagination.key?(:hits)
    assert pagination.key?(:prev)
    assert pagination.key?(:page)

    assert_nil pagination[:next]
  end
end
