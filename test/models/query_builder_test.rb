require 'test_helper'

class QueryBuilderTest < ActiveSupport::TestCase
  test 'query builder trims spaces' do
    expected = { 'from' => '0', 'q' => 'blah', 'queryMode' => 'keyword', 'index' => 'FAKE_TIMDEX_INDEX' }
    search = { q: ' blah ' }
    assert_equal(expected, QueryBuilder.new(search).query)
  end

  test 'query builder handles supported fields' do
    expected = { 'from' => '0', 'q' => 'blah',
                 'citation' => 'Citations are cool. Journal of cool citations. Vol 3, page 123.',
                 'contributors' => 'Vonnegut, Kurt', 'fundingInformation' => 'National Science Foundation',
                 'identifiers' => 'doi://1234.123/123.123', 'locations' => 'Cambridge, MA',
                 'subjects' => 'Subjects are the worst', 'title' => 'Hi I like titles', 'queryMode' => 'keyword', 'index' => 'FAKE_TIMDEX_INDEX' }
    search = {
      q: ' blah ',
      citation: 'Citations are cool. Journal of cool citations. Vol 3, page 123.',
      contributors: 'Vonnegut, Kurt',
      fundingInformation: 'National Science Foundation',
      identifiers: 'doi://1234.123/123.123',
      locations: 'Cambridge, MA',
      subjects: 'Subjects are the worst',
      title: 'Hi I like titles'
    }
    assert_equal(expected, QueryBuilder.new(search).query)
  end

  test 'query builder ignores unsupported fields' do
    expected = { 'from' => '0', 'q' => 'blah',
                 'citation' => 'Citations are cool. Journal of cool citations. Vol 3, page 123.',
                 'contributors' => 'Vonnegut, Kurt', 'fundingInformation' => 'National Science Foundation',
                 'identifiers' => 'doi://1234.123/123.123', 'locations' => 'Cambridge, MA',
                 'subjects' => 'Subjects are the worst', 'title' => 'Hi I like titles', 'queryMode' => 'keyword', 'index' => 'FAKE_TIMDEX_INDEX' }
    search = {
      q: ' blah ',
      citation: 'Citations are cool. Journal of cool citations. Vol 3, page 123.',
      contributors: 'Vonnegut, Kurt',
      fundingInformation: 'National Science Foundation',
      identifiers: 'doi://1234.123/123.123',
      locations: 'Cambridge, MA',
      subjects: 'Subjects are the worst',
      title: 'Hi I like titles',
      fake: 'I will not show up in the output'
    }
    assert_equal(expected, QueryBuilder.new(search).query)
  end

  test 'query builder ignores supported fields that were not included' do
    expected = { 'from' => '0', 'q' => 'blah', 'contributors' => 'Vonnegut, Kurt',
                 'fundingInformation' => 'National Science Foundation',
                 'identifiers' => 'doi://1234.123/123.123', 'queryMode' => 'keyword', 'index' => 'FAKE_TIMDEX_INDEX' }
    search = {
      q: ' blah ',
      contributors: 'Vonnegut, Kurt',
      fundingInformation: 'National Science Foundation',
      identifiers: 'doi://1234.123/123.123'
    }
    assert_equal(expected, QueryBuilder.new(search).query)
  end

  test 'query builder can read TIMDEX_INDEX from env' do
    ClimateControl.modify TIMDEX_INDEX: 'rdi*' do
      search = { q: 'blah' }
      assert_equal('rdi*', QueryBuilder.new(search).query['index'])
    end
  end

  test 'query builder index is nil if TIMDEX_INDEX not provided in env' do
    ClimateControl.modify TIMDEX_INDEX: nil do
      search = { q: 'blah' }
      assert_nil(QueryBuilder.new(search).query['index'])
    end
  end

  # Geospatial search behavior
  test 'query builder handles supported geospatial fields and converts lat/long to float' do
    ClimateControl.modify FEATURE_GEODATA: 'true' do
      expected = {
        'from' => '0',
        'geobox' => 'true',
        'geodistance' => 'true',
        'geoboxMinLongitude' => 40.5,
        'geoboxMinLatitude' => 90.0,
        'geoboxMaxLongitude' => 78.2,
        'geoboxMaxLatitude' => 180.0,
        'geodistanceLatitude' => 36.1,
        'geodistanceLongitude' => 62.6,
        'geodistanceDistance' => '50mi',
        'queryMode' => 'keyword',
        'index' => 'FAKE_TIMDEX_INDEX'
      }
      search = {
        geobox: 'true',
        geodistance: 'true',
        geoboxMinLongitude: '40.5',
        geoboxMinLatitude: '90.0',
        geoboxMaxLongitude: '78.2',
        geoboxMaxLatitude: '180.0',
        geodistanceLatitude: '36.1',
        geodistanceLongitude: '62.6',
        geodistanceDistance: '50mi'
      }
      assert_equal expected, QueryBuilder.new(search).query
    end
  end

  test 'query builder ignores geospatial fields if feature flag is off' do
    expected = {
      'from' => '0',
      'queryMode' => 'keyword',
      'index' => 'FAKE_TIMDEX_INDEX'
    }
    search = {
      geoboxMinLongitude: '40.5',
      geoboxMinLatitude: '90.0',
      geoboxMaxLongitude: '78.2',
      geoboxMaxLatitude: '180.0',
      geodistanceLatitude: '36.1',
      geodistanceLongitude: '62.6',
      geodistanceDistance: '50mi'
    }
    assert_equal expected, QueryBuilder.new(search).query
  end

  test 'query builder defaults to keyword queryMode' do
    search = { q: 'blah' }
    assert_equal('keyword', QueryBuilder.new(search).query['queryMode'])
  end

  test 'query builder uses queryMode URL parameter for semantic' do
    search = { q: 'blah', queryMode: 'semantic' }
    assert_equal('semantic', QueryBuilder.new(search).query['queryMode'])
  end

  test 'query builder uses queryMode URL parameter for hybrid' do
    search = { q: 'blah', queryMode: 'hybrid' }
    assert_equal('hybrid', QueryBuilder.new(search).query['queryMode'])
  end

  test 'query builder explicitly sets queryMode for keyword parameter' do
    search = { q: 'blah', queryMode: 'keyword' }
    assert_equal('keyword', QueryBuilder.new(search).query['queryMode'])
  end

  test 'query builder uses DEFAULT_QUERY_MODE config when parameter absent' do
    ClimateControl.modify DEFAULT_QUERY_MODE: 'semantic' do
      search = { q: 'blah' }
      assert_equal('semantic', QueryBuilder.new(search).query['queryMode'])
    end
  end

  test 'query builder URL parameter takes precedence over DEFAULT_QUERY_MODE' do
    ClimateControl.modify DEFAULT_QUERY_MODE: 'semantic' do
      search = { q: 'blah', queryMode: 'keyword' }
      assert_equal('keyword', QueryBuilder.new(search).query['queryMode'])
    end
  end

  test 'query builder falls back to keyword for invalid queryMode parameter' do
    search = { q: 'blah', queryMode: 'invalid_mode' }
    assert_equal('keyword', QueryBuilder.new(search).query['queryMode'])
  end

  test 'query builder falls back to keyword for blank queryMode parameter' do
    search = { q: 'blah', queryMode: '' }
    assert_equal('keyword', QueryBuilder.new(search).query['queryMode'])
  end

  test 'query builder falls back to keyword for invalid DEFAULT_QUERY_MODE' do
    ClimateControl.modify DEFAULT_QUERY_MODE: 'invalid_mode' do
      search = { q: 'blah' }
      assert_equal('keyword', QueryBuilder.new(search).query['queryMode'])
    end
  end

  test 'query builder falls back to keyword for blank DEFAULT_QUERY_MODE' do
    ClimateControl.modify DEFAULT_QUERY_MODE: '' do
      search = { q: 'blah' }
      assert_equal('keyword', QueryBuilder.new(search).query['queryMode'])
    end
  end

  test 'query builder handles queryMode with whitespace' do
    search = { q: 'blah', queryMode: '  semantic  ' }
    assert_equal('semantic', QueryBuilder.new(search).query['queryMode'])
  end
end
