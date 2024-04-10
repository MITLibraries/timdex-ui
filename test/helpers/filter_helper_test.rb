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
    assert_includes add_filter(original_query, :contentTypeFilter, 'dataset'), 'dataset'
  end

  test 'add_filter will reset a page count when called' do
    original_query = {
      page: 3,
      q: 'data'
    }

    assert_includes add_filter(original_query, :contentTypeFilter, 'dataset'), 'page=1'
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
    assert_includes add_filter(original_query, :contentTypeFilter, 'dataset'),
                    'contentTypeFilter%5B%5D=still+image&contentTypeFilter%5B%5D=dataset'
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
    assert_includes add_filter(original_query, :sourceFilter, 'source the only'), 'source+the+only'
    assert_not_includes add_filter(original_query, :sourceFilter, 'source the only'), 
                        'source+the+second'
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
    assert_not_includes remove_filter(original_query, :contentTypeFilter, 'dataset'), 'dataset'
  end

  test 'remove_filter will reset a page count when called' do
    original_query = {
      page: 3,
      q: 'data',
      contentTypeFilter: ['dataset']
    }
    assert_includes remove_filter(original_query, :contentTypeFilter, 'dataset'), 'page=1'
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
    assert_includes remove_filter(original_query, :contentTypeFilter, 'microfiche'), 'dataset'
    assert_includes remove_filter(original_query, :contentTypeFilter, 'microfiche'), 'vinyl+record'
    assert_not_includes remove_filter(original_query, :contentTypeFilter, 'microfiche'), 'microfiche'
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
    query = {
      contentTypeFilter: ['dataset'],
      sourceFilter: ['my imagination']
    }
    assert_equal [{ contentTypeFilter: 'dataset' }, { sourceFilter: 'my imagination' }], applied_filters(query)
  end

  test 'applied_filters collects separately terms in the same filter category' do
    query = {
      contentTypeFilter: ['dataset', 'language material'],
      sourceFilter: ['my imagination']
    }
    assert_equal [{ contentTypeFilter: 'dataset' }, { contentTypeFilter: 'language material' },
                  { sourceFilter: 'my imagination' }], applied_filters(query)
  end

  test 'applied_filters does not return search term params' do
    query = {
      q: 'jazz',
      advanced: true,
      title: 'undercurrent',
      contributors: ['evans, bill', 'hall, jim'],
      contentTypeFilter: ['lp']
    }
    assert_equal [{ contentTypeFilter: 'lp' }], applied_filters(query)
  end

  test 'applied_filters does not return other unwanted parts of the enhanced query' do
    query = {
      page: 2,
      advanced: true,
      contentTypeFilter: ['dataset']
    }
    assert_equal [{ contentTypeFilter: 'dataset' }], applied_filters(query)
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

  test 'remove_all_filters removes one filter' do
    query = {
      q: 'jazz',
      contributorsFilter: ['evans, bill', 'hall, jim'],
    }
    assert_equal({ q: 'jazz', page: 1 }, remove_all_filters(query))
  end

  test 'remove_all_filters removes multiple filters' do
    query = {
      q: 'jazz',
      contributorsFilter: ['evans, bill', 'hall, jim'],
      contentTypeFilter: ['lp'],
      accessToFilesFilter: ['no authentication required']
    }
    assert_equal({ q: 'jazz', page: 1 }, remove_all_filters(query))
  end

  test 'remove_all_filters resets the page number' do
    query = {
      q: 'jazz',
      contributorsFilter: ['evans, bill', 'hall, jim'],
      page: 22
    }
    assert_equal({ q: 'jazz', page: 1 }, remove_all_filters(query))
  end

  test 'remove_all_filters does not change non-filter search terms' do
    query = {
      q: 'jazz',
      advanced: true,
      title: 'undercurrent',
      contributors: ['evans, bill', 'hall, jim'],
      contentTypeFilter: ['lp']
    }
    assert_equal({ q: 'jazz', advanced: true, title: 'undercurrent', contributors: ['evans, bill', 'hall, jim'],
                   page: 1 }, remove_all_filters(query))
  end


  test 'applied_filters are returned in the order of application' do
    query = {
      q: 'jazz',
      page: 1,
      contributorsFilter: ['evans, bill', 'hall, jim'],
      subjectsFilter: ['jazz'],
      placesFilter: ['New York'],
      contentTypeFilter: ['lp'],
    }
      assert_equal [{ contributorsFilter: 'evans, bill' }, { contributorsFilter: 'hall, jim' },
                    { subjectsFilter: 'jazz' }, { placesFilter: 'New York' }, { contentTypeFilter: 'lp' }],
                    applied_filters(query)
  end

  test 'applied_filters handles single-valued and multi-valued filters' do
    query = {
      contributorsFilter: ['liu, cixin'],
      literaryFormFilter: 'fiction'
    }
      assert_equal [{ contributorsFilter: 'liu, cixin' }, { literaryFormFilter: 'fiction' }],
                    applied_filters(query)
  end

  test 'add_filter URLs retain preserve order' do
    query = {
      q: 'jazz',
      page: 1,
      contributorsFilter: ['evans, bill', 'hall, jim'],
      subjectsFilter: ['jazz'],
      placesFilter: ['New York'],
    }
    assert_includes add_filter(query, :contentTypeFilter, 'lp'),
                    'contributorsFilter%5B%5D=evans%2C+bill&contributorsFilter%5B%5D=hall%2C+jim&subjectsFilter%5B%5D=jazz&placesFilter%5B%5D=New+York&contentTypeFilter%5B%5D=lp'

  end

  test 'remove_filter URLs preserve order' do
    query = {
      q: 'jazz',
      page: 1,
      contributorsFilter: ['evans, bill', 'hall, jim'],
      subjectsFilter: ['jazz'],
      placesFilter: ['New York'],
      contentTypeFilter: ['lp'],
    }
    assert_includes remove_filter(query, :contentTypeFilter, 'lp'),
                    'contributorsFilter%5B%5D=evans%2C+bill&contributorsFilter%5B%5D=hall%2C+jim&subjectsFilter%5B%5D=jazz&placesFilter%5B%5D=New+York'
  end

  test 'single- and multi-valued filters are correctly parsed in filter URLs' do
    query = {
      q: 'data',
      page: 1
    }
    multivalue_query = add_filter(query, :subjectsFilter, 'data')
    singlevalue_query = add_filter(query, :literaryFormFilter, 'nonfiction')
    assert_includes multivalue_query, 'subjectsFilter%5B%5D=data'
    assert_includes singlevalue_query, 'literaryFormFilter=nonfiction'
  end
end
