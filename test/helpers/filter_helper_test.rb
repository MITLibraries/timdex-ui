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
      contentTypeFilter: ['dataset']
    }
    assert_equal expected_query, add_filter(original_query, :contentTypeFilter, 'dataset')
  end

  test 'add_filter will reset a page count when called' do
    original_query = {
      page: 3,
      q: 'data'
    }
    expected_query = {
      page: 1,
      q: 'data',
      contentTypeFilter: ['dataset']
    }
    assert_equal expected_query, add_filter(original_query, :contentTypeFilter, 'dataset')
  end

  test 'add_filter can apply multiple values for each filter group' do
    original_query = {
      page: 3,
      q: 'data',
      contentTypeFilter: ['still image']
    }
    expected_query = {
      page: 1,
      q: 'data',
      contentTypeFilter: ['still image', 'dataset']
    }
    assert_equal expected_query, add_filter(original_query, :contentTypeFilter, 'dataset')
  end

  test 'add_filter with source value overwrites existing sources' do
    original_query = {
      page: 3,
      q: 'data',
      sourceFilter: ['source the first', 'source the second']
    }
    expected_query = {
      page: 1,
      q: 'data',
      sourceFilter: ['source the only']
    }
    assert_equal expected_query, add_filter(original_query, :sourceFilter, 'source the only')
  end

  test 'nice_labels allows translation of machine categories to human readable headings' do
    needle = :contentTypeFilter
    assert_equal 'Content type', nice_labels[needle]
  end

  test 'nice_labels returns nil if a category is not mapped yet' do
    needle = :foo
    assert_nil nice_labels[needle]
  end

  test 'nice_labels will use a value from ENV instead of the default if provided' do
    label = 'Content type'
    ClimateControl.modify FILTER_CONTENT_TYPE: nil do
      needle = :contentTypeFilter
      assert_equal label, nice_labels[needle]
    end
    label = 'Custom label'
    ClimateControl.modify FILTER_CONTENT_TYPE: label do
      needle = :contentTypeFilter
      assert_equal label, nice_labels[needle]
    end
  end

  test 'remove_filter will remove a specific filter parameter from a search URL' do
    original_query = {
      page: 1,
      q: 'data',
      contentTypeFilter: ['dataset']
    }
    expected_query = {
      page: 1,
      q: 'data'
    }
    assert_equal expected_query, remove_filter(original_query, :contentTypeFilter, 'dataset')
  end

  test 'remove_filter will reset a page count when called' do
    original_query = {
      page: 3,
      q: 'data',
      contentTypeFilter: ['dataset']
    }
    expected_query = {
      page: 1,
      q: 'data'
    }
    assert_equal expected_query, remove_filter(original_query, :contentTypeFilter, 'dataset')
  end

  test 'remove_filter removes only one filter parameter if multiple are applied' do
    original_query = {
      page: 3,
      q: 'data',
      contentTypeFilter: ['dataset', 'microfiche', 'vinyl record']
    }
    expected_query = {
      page: 1,
      q: 'data',
      contentTypeFilter: ['dataset', 'vinyl record']
    }
    assert_equal expected_query, remove_filter(original_query, :contentTypeFilter, 'microfiche')
  end

  test 'filter_applied? returns true if a filter is applied' do
    query = {
      page: 3,
      q: 'data',
      contentTypeFilter: ['dataset']
    }
    assert filter_applied?(query[:contentTypeFilter], 'dataset')
  end

  test 'filter_applied? returns false if the filter does not include the target term' do
    query = {
      page: 3,
      q: 'data',
      contentTypeFilter: ['dataset']
    }
    assert_not filter_applied?(query[:contentTypeFilter], 'microfiche')
  end

  # This is an unlikely state to reach, but better safe than sorry
  test 'filter_applied? returns false if no filter is supplied in the query' do
    query = {
      page: 3,
      q: 'data',
    }
    assert_not filter_applied?(query[:contentTypeFilter], 'dataset')
  end

  test 'applied_filters returns all currently applied filters' do
    @enhanced_query = {
      contentTypeFilter: ['dataset'],
      sourceFilter: ['my imagination']
    }
    assert_equal [{ contentTypeFilter: 'dataset' }, { sourceFilter: 'my imagination' }], applied_filters
  end

  test 'applied_filters collects separately terms in the same filter category' do
    @enhanced_query = {
      contentTypeFilter: ['dataset'],
      sourceFilter: ['my imagination']
    }
    assert_equal [{ contentTypeFilter: 'dataset' }, { sourceFilter: 'my imagination' }], applied_filters
  end

  test 'applied_filters does not return search term params' do
    @enhanced_query = {
      q: 'jazz',
      advanced: true,
      title: 'undercurrent',
      contributors: ['evans, bill', 'hall, jim'],
      contentTypeFilter: ['lp']
    }
    assert_equal [{ contentTypeFilter: 'lp' }], applied_filters
  end

  test 'applied_filters does not return other unwanted parts of the enhanced query' do
    @enhanced_query = {
      page: 2,
      advanced: true,
      contentTypeFilter: ['dataset']
    }
    assert_equal [{ contentTypeFilter: 'dataset' }], applied_filters
  end

  test 'gdt_sources returns the source label we want for MIT stuff' do
    assert_equal 'MIT', gdt_sources('mit gis resources', :sourceFilter)
  end

  test 'gdt_sources returns the source label we want for non-MIT stuff' do
    assert_equal 'Non-MIT institutions', gdt_sources('opengeometadata gis resources', :sourceFilter)
  end

  test 'gdt_sources returns the source label as-is if we have no translation for it' do
    assert_equal 'geodude', gdt_sources('geodude', :sourceFilter)
  end

  test 'gdt_sources returns the label as-is for non-source filters' do
    assert_equal 'me', gdt_sources('me', :contributorsFilter)
    assert_equal 'GIS', gdt_sources('GIS', :subjectsFilter)
  end
end
