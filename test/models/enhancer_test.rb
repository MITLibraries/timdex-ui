require 'test_helper'

class EnhancerTest < ActiveSupport::TestCase
  def setup
    @test_strategy = Flipflop::FeatureSet.current.test!
  end
  def teardown
    @test_strategy = Flipflop::FeatureSet.current.test!
  end

  test 'enhanced_query with no matched patterns returns raw query and q' do
    url = 'https://example.org/results?q=hallo'

    eq = Enhancer.new(url)
    assert_equal 'hallo', eq.enhanced_query[:q]
  end

  test 'enhanced_query does not set values for unmatched term_patterns' do
    url = 'https://example.org/results?q=hallo'

    eq = Enhancer.new(url)

    assert_nil eq.enhanced_query[:issn]
    assert_nil eq.enhanced_query[:isbn]
  end

  test 'enhanced_query returns keys and values for matched patterns' do
    url = 'https://example.org/results?q=hallo+978-3-16-148410-0+goodbye'

    eq = Enhancer.new(url)

    assert_equal '978-3-16-148410-0', eq.enhanced_query[:isbn]
  end

  test 'enhanced_query can match multiple patterns' do
    url = 'https://example.org/results?q=hallo+978-3-16-148410-0+goodbye+1234-5678+popcorn'

    eq = Enhancer.new(url)

    assert_equal '978-3-16-148410-0', eq.enhanced_query[:isbn]
    assert_equal '1234-5678', eq.enhanced_query[:issn]
  end

  # Page parameter
  test 'enhanced_query recieves page values in positive numbers' do
    url = 'https://example.org/results?q=singleton&page=3'

    eq = Enhancer.new(url)
    assert_equal 3, eq.enhanced_query[:page]
  end

  test 'enhanced_query converts decimal page values to integers' do
    url = 'https://example.org/results?q=singleton&page=6.02'

    eq = Enhancer.new(url)
    assert_equal 6, eq.enhanced_query[:page]
  end

  test 'enhanced_query sets a default page value if none received' do
    url = 'https://example.org/results?q=singleton'

    eq = Enhancer.new(url)
    assert_equal 1, eq.enhanced_query[:page]
  end

  test 'enhanced_query deals with negative page numbers' do
    url = 'https://example.org/results?q=singleton&page=-100'

    eq = Enhancer.new(url)
    assert_equal 1, eq.enhanced_query[:page]
  end

  test 'enhanced_query deals with gibberish' do
    url = 'https://example.org/results?q=singleton&page=foo'

    eq = Enhancer.new(url)
    assert_equal 1, eq.enhanced_query[:page]
  end

  test 'enhanced_query extracts geospatial fields' do
    @test_strategy.switch!(:gdt, true)

    url = 'https://example.org/results?q=&geobox=true&geoboxMinLongitude=-73.51&geoboxMinLatitude=41.24' \
          '&geoboxMaxLongitude=-69.93&geoboxMaxLatitude=42.89&geodistance=true&geodistanceLatitude=42.28' \
          '&geodistanceLongitude=-83.73&geodistanceDistance=50mi'
    eq = Enhancer.new(url)
    assert_equal 'true', eq.enhanced_query[:geobox]
    assert_equal 'true', eq.enhanced_query[:geodistance]
    assert_equal '-73.51', eq.enhanced_query[:geoboxMinLongitude]
    assert_equal '41.24', eq.enhanced_query[:geoboxMinLatitude]
    assert_equal '-69.93', eq.enhanced_query[:geoboxMaxLongitude]
    assert_equal '42.89', eq.enhanced_query[:geoboxMaxLatitude]
    assert_equal '42.28', eq.enhanced_query[:geodistanceLatitude]
    assert_equal '-83.73', eq.enhanced_query[:geodistanceLongitude]
    assert_equal '50mi', eq.enhanced_query[:geodistanceDistance]
  end

  test 'enhanced_query does not extract geospatial fields if GDT feature flag is disabled' do
    @test_strategy.switch!(:gdt, false)

    url = 'https://example.org/results?q=&geobox=true&geoboxMinLongitude=-73.51&geoboxMinLatitude=41.24' \
          '&geoboxMaxLongitude=-69.93&geoboxMaxLatitude=42.89&geodistance=true&geodistanceLatitude=42.28' \
          '&geodistanceLongitude=-83.73&geodistanceDistance=50mi'
    eq = Enhancer.new(url)
    assert_nil eq.enhanced_query[:geobox]
    assert_nil eq.enhanced_query[:geodistance]
    assert_nil eq.enhanced_query[:geoboxMinLongitude]
    assert_nil eq.enhanced_query[:geoboxMaxLatitude]
    assert_nil eq.enhanced_query[:geoboxMaxLongitude]
    assert_nil eq.enhanced_query[:geoboxMaxLatitude]
    assert_nil eq.enhanced_query[:geodistanceLatitude]
    assert_nil eq.enhanced_query[:geodistanceLongitude]
    assert_nil eq.enhanced_query[:geodistanceDistance]
  end
end
