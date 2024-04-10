require 'test_helper'

class QueryBuilderTest < ActiveSupport::TestCase
  def setup
    @test_strategy = Flipflop::FeatureSet.current.test!
  end
  def teardown
    @test_strategy = Flipflop::FeatureSet.current.test!
  end

  test 'query builder trims spaces' do
    expected = { 'from' => '0', 'q' => 'blah', 'index' => 'FAKE_TIMDEX_INDEX' }
    search = { q: ' blah ' }
    assert_equal(expected, QueryBuilder.new(search).query)
  end

  test 'query builder handles supported fields' do
    expected = { 'from' => '0', 'q' => 'blah',
                 'citation' => 'Citations are cool. Journal of cool citations. Vol 3, page 123.',
                 'contributors' => 'Vonnegut, Kurt', 'fundingInformation' => 'National Science Foundation',
                 'identifiers' => 'doi://1234.123/123.123', 'locations' => 'Cambridge, MA',
                 'subjects' => 'Subjects are the worst', 'title' => 'Hi I like titles', 'index' => 'FAKE_TIMDEX_INDEX' }
    search = {
      q: 'blah',
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
                 'subjects' => 'Subjects are the worst', 'title' => 'Hi I like titles', 'index' => 'FAKE_TIMDEX_INDEX' }
    search = {
      q: 'blah',
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
                 'identifiers' => 'doi://1234.123/123.123', 'index' => 'FAKE_TIMDEX_INDEX' }
    search = {
      q: 'blah',
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
    @test_strategy.switch!(:gdt, true)

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

  test 'query builder ignores geospatial fields if feature flag is off' do
    @test_strategy.switch!(:gdt, false)

    expected = { 
                 'from' => '0',
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
end
