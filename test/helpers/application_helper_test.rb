require 'test_helper'

class FilterHelperTest < ActionView::TestCase
  include ApplicationHelper

  test 'index_page_title renders as expected' do
    assert_equal 'Search | MIT Libraries', index_page_title
  end

  test 'results_page_title includes keyword search terms' do
    query = { q: 'National Parks Service' }
    assert_equal 'National Parks Service | MIT Libraries', results_page_title(query)
  end

  test 'results_page_title excludes irrelevant query params' do
    query = { q: 'National Parks Service', page: 1, geobox: 'true', geodistance: 'true', advanced: 'true' }
    assert_equal 'National Parks Service | MIT Libraries', results_page_title(query)
  end

  test 'results_page_title includes advanced search terms' do
    query = { title: 'Sister Outsider', contributors: ['Lorde, Audre'] }
    assert_equal 'Sister Outsider Lorde, Audre | MIT Libraries', results_page_title(query)
  end

  test 'results_page_title includes geospatial search terms' do
    query = { geodistanceLatitude: '42.281389', geodistanceLongitude: '-83.748333', geodistanceDistance: '29.09mi' }
    assert_equal '42.281389 -83.748333 29.09mi | MIT Libraries', results_page_title(query)
  end

  test 'results_page_title truncates terms above character limit' do
    query = { q: 'National Park Service Land Resources Division tract and boundary data' }

    # Default character limit (50)
    assert_equal 'National Park Service Land Resources Division trac... | MIT Libraries',
                 results_page_title(query)

    # Custom character limit
    assert_equal 'National Park S... | MIT Libraries', results_page_title(query, 15)
  end

  test 'results_page_title returns index_page_title if there is no enhanced query for some reason' do
    no_query = nil
    assert_equal 'Search | MIT Libraries', results_page_title(no_query)
  end

  test 'record_page_title includes record title' do
    record = { 'title' => 'The Waves' }
    assert_equal 'The Waves | MIT Libraries', record_page_title(record)
  end

  test 'record_page_title truncates titles above the character limit' do
    record = { 'title' => 'Indigenous Continent: The Epic Contest for North America | GeoData | MIT Libraries' }

    # Default character limit (25)
    assert_equal 'Indigenous Continent: The... | MIT Libraries',
                 record_page_title(record)

    # Custom character limit
    assert_equal 'Indigenous Continent... | MIT Libraries', record_page_title(record, 20)
  end

  test 'record_page_title returns index_page_title if there is no record or title for some reason' do
    absence_of_record = nil
    no_title = { 'recordId' => 'foo.bar' }
    assert_equal 'Search | MIT Libraries', record_page_title(absence_of_record)
    assert_equal 'Search | MIT Libraries', record_page_title(no_title)
  end

  test 'page titles can include platform name' do
    ClimateControl.modify PLATFORM_NAME: 'GeoData' do
      query = { q: 'foo' }
      record = { 'title' => 'bar' }
      assert_equal 'Search GeoData | MIT Libraries', index_page_title
      assert_equal 'foo | GeoData | MIT Libraries', results_page_title(query)
      assert_equal 'bar | GeoData | MIT Libraries', record_page_title(record)
    end
  end
end
