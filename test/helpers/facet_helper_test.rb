require 'test_helper'

class FacetHelperTest < ActionView::TestCase
  include FacetHelper

  test 'add_facet will support adding a facet parameter to a search URL' do
    original_query = {
      page: 1,
      q: 'data'
    }
    expected_query = {
      page: 1,
      q: 'data',
      'contentType' => ['dataset']
    }
    assert_equal expected_query, add_facet(original_query, 'contentType', 'dataset')
  end

  test 'add_facet will reset a page count when called' do
    original_query = {
      page: 3,
      q: 'data'
    }
    expected_query = {
      page: 1,
      q: 'data',
      'contentType' => ['dataset']
    }
    assert_equal expected_query, add_facet(original_query, 'contentType', 'dataset')
  end

  test 'add_facet can apply multiple values for each facet group' do
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
    assert_equal expected_query, add_facet(original_query, 'contentType', 'dataset')
  end

  test 'add_facet with source value overwrites existing sources' do
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
    assert_equal expected_query, add_facet(original_query, 'source', 'source the only')
  end

  test 'nice_labels allows translation of machine categories to human readable headings' do
    needle = 'contentType'
    assert_equal 'Content types', nice_labels[needle]
  end

  test 'nice_labels returns nil if a category is not mapped yet' do
    needle = 'foo'
    assert_nil nice_labels[needle]
  end

  test 'remove_facet will remove a specific facet parameter from a search URL' do
    original_query = {
      page: 1,
      q: 'data',
      contentType: 'dataset'
    }
    expected_query = {
      page: 1,
      q: 'data'
    }
    assert_equal expected_query, remove_facet(original_query, 'contentType')
  end

  test 'remove_facet will reset a page count when called' do
    original_query = {
      page: 3,
      q: 'data',
      contentType: 'dataset'
    }
    expected_query = {
      page: 1,
      q: 'data'
    }
    assert_equal expected_query, remove_facet(original_query, 'contentType')
  end
end
