require 'test_helper'

class FilterHelperTest < ActionView::TestCase
  include FilterHelper

  test 'add_filter will support adding a filter parameter to a search URL' do
    original_query = {
      page: 1,
      q: 'data'
    }
    expected_query = {
      page: 1,
      q: 'data',
      'contentType' => ['dataset']
    }
    assert_equal expected_query, add_filter(original_query, 'contentType', 'dataset')
  end

  test 'add_filter will reset a page count when called' do
    original_query = {
      page: 3,
      q: 'data'
    }
    expected_query = {
      page: 1,
      q: 'data',
      'contentType' => ['dataset']
    }
    assert_equal expected_query, add_filter(original_query, 'contentType', 'dataset')
  end

  test 'add_filter can apply multiple values for each filter group' do
    original_query = {
      page: 3,
      q: 'data',
      'contentType' => ['still image']
    }
    expected_query = {
      page: 1,
      q: 'data',
      'contentType' => ['still image', 'dataset']
    }
    assert_equal expected_query, add_filter(original_query, 'contentType', 'dataset')
  end

  test 'add_filter with source value overwrites existing sources' do
    original_query = {
      page: 3,
      q: 'data',
      'source' => ['source the first', 'source the second']
    }
    expected_query = {
      page: 1,
      q: 'data',
      'source' => ['source the only']
    }
    assert_equal expected_query, add_filter(original_query, 'source', 'source the only')
  end

  test 'nice_labels allows translation of machine categories to human readable headings' do
    needle = 'contentType'
    assert_equal 'Content types', nice_labels[needle]
  end

  test 'nice_labels returns nil if a category is not mapped yet' do
    needle = 'foo'
    assert_nil nice_labels[needle]
  end

  test 'remove_filter will remove a specific filter parameter from a search URL' do
    original_query = {
      page: 1,
      q: 'data',
      contentType: ['dataset']
    }
    expected_query = {
      page: 1,
      q: 'data'
    }
    assert_equal expected_query, remove_filter(original_query, :contentType, 'dataset')
  end

  test 'remove_filter will reset a page count when called' do
    original_query = {
      page: 3,
      q: 'data',
      contentType: ['dataset']
    }
    expected_query = {
      page: 1,
      q: 'data'
    }
    assert_equal expected_query, remove_filter(original_query, :contentType, 'dataset')
  end

  test 'remove_filter removes only one filter parameter if multiple are applied' do
    original_query = {
      page: 3,
      q: 'data',
      contentType: ['dataset', 'microfiche', 'vinyl record']
    }
    expected_query = {
      page: 1,
      q: 'data',
      contentType: ['dataset', 'vinyl record']
    }
    assert_equal expected_query, remove_filter(original_query, :contentType, 'microfiche')
  end

  test 'filter_applied? returns true if a filter is applied' do
    query = {
      page: 3,
      q: 'data',
      contentType: ['dataset']
    }
    assert filter_applied?(query[:contentType], 'dataset')
  end

  test 'filter_applied? returns false if the filter does not include the target term' do
    query = {
      page: 3,
      q: 'data',
      contentType: ['dataset']
    }
    assert_not filter_applied?(query[:contentType], 'microfiche')
  end

  # This is an unlikely state to reach, but better safe than sorry
  test 'filter_applied? returns false if no filter is supplied in the query' do
    query = {
      page: 3,
      q: 'data',
    }
    assert_not filter_applied?(query[:contentType], 'dataset')
  end
end
