require 'test_helper'

class EnhancerTest < ActiveSupport::TestCase
  def setup
    @test_strategy = Flipflop::FeatureSet.current.test!
  end
  def teardown
    @test_strategy = Flipflop::FeatureSet.current.test!
  end

  test 'enhanced_query with no matched patterns returns raw query and q' do
    params = {}
    params[:q] = 'hallo'

    eq = Enhancer.new(params)
    assert_equal params[:q], eq.enhanced_query[:q]
  end

  test 'enhanced_query does not set values for unmatched term_patterns' do
    params = {}
    params[:q] = 'hallo'

    eq = Enhancer.new(params)

    assert_nil eq.enhanced_query[:issn]
    assert_nil eq.enhanced_query[:isbn]
  end

  test 'enhanced_query returns keys and values for matched patterns' do
    params = {}
    params[:q] = 'hallo 978-3-16-148410-0 goodbye'

    eq = Enhancer.new(params)

    assert_equal '978-3-16-148410-0', eq.enhanced_query[:isbn]
  end

  test 'enhanced_query can match multiple patterns' do
    params = {}
    params[:q] = 'hallo 978-3-16-148410-0 goodbye 1234-5678 popcorn'

    eq = Enhancer.new(params)

    assert_equal '978-3-16-148410-0', eq.enhanced_query[:isbn]
    assert_equal '1234-5678', eq.enhanced_query[:issn]
  end

  # Page parameter
  test 'enhanced_query recieves page values in positive numbers' do
    params = {}
    params[:q] = 'singleton'
    params[:page] = 3

    eq = Enhancer.new(params)
    assert_equal 3, eq.enhanced_query[:page]
  end

  test 'enhanced_query recieves page values as strings' do
    params = {}
    params[:q] = 'singleton'
    params[:page] = '3'

    eq = Enhancer.new(params)
    assert_equal 3, eq.enhanced_query[:page]
  end

  test 'enhanced_query converts decimal page values to integers' do
    params = {}
    params[:q] = 'singleton'
    params[:page] = '6.02'

    eq = Enhancer.new(params)
    assert_equal 6, eq.enhanced_query[:page]
  end

  test 'enhanced_query sets a default page value if none received' do
    params = {}
    params[:q] = 'singleton'

    eq = Enhancer.new(params)
    assert_equal 1, eq.enhanced_query[:page]
  end

  test 'enhanced_query deals with negative page numbers' do
    params = {}
    params[:q] = 'singleton'
    params[:page] = '-100'

    eq = Enhancer.new(params)
    assert_equal 1, eq.enhanced_query[:page]
  end

  test 'enhanced_query deals with gibberish' do
    params = {}
    params[:q] = 'singleton'
    params[:page] = 'foo'

    eq = Enhancer.new(params)
    assert_equal 1, eq.enhanced_query[:page]
  end

  test 'enhanced_query extracts geospatial fields' do
    @test_strategy.switch!(:gdt, true)

    params = {
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
     eq = Enhancer.new(params)
     assert_equal 'true', eq.enhanced_query[:geobox]
     assert_equal 'true', eq.enhanced_query[:geodistance]
     assert_equal '40.5', eq.enhanced_query[:geoboxMinLongitude]
     assert_equal '90.0', eq.enhanced_query[:geoboxMinLatitude]
     assert_equal '78.2', eq.enhanced_query[:geoboxMaxLongitude]
     assert_equal '180.0', eq.enhanced_query[:geoboxMaxLatitude]
     assert_equal '36.1', eq.enhanced_query[:geodistanceLatitude]
     assert_equal '62.6', eq.enhanced_query[:geodistanceLongitude]
     assert_equal '50mi', eq.enhanced_query[:geodistanceDistance]
  end

  test 'enhanced_query does not extract geospatial fields if GDT feature flag is disabled' do
    @test_strategy.switch!(:gdt, false)

    params = {
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
     eq = Enhancer.new(params)
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
