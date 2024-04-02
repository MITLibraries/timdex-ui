require 'test_helper'

# Geospatial search behavior
class SearchControllerGeoTest < ActionDispatch::IntegrationTest
  def setup
    @test_strategy = Flipflop::FeatureSet.current.test!
    @test_strategy.switch!(:gdt, true)
  end

  test 'GDT has specific advanced search fields' do
    get '/'

    # Please note that this test confirms fields in the DOM - but not whether
    # they are visible. Fields in a hidden details panel are still in the DOM,
    # but not visible or reachable via keyboard interaction.
    assert_select 'input#advanced-title', count: 1
    assert_select 'input#advanced-contributors', count: 1
    assert_select 'input#advanced-locations', count: 1
    assert_select 'input#advanced-subjects', count: 1
    assert_select 'input.source', count: 0
    assert_select 'input#advanced-citation', count: 0
    assert_select 'input#advanced-fundingInformation', count: 0
    assert_select 'input#advanced-identifiers', count: 0
  end

  test 'contributors label is renamed to authors in GDT' do
    get '/'
    assert_select 'label', text: "Authors"
  end

  test 'index shows geobox form, closed by default' do
    get '/'
    assert_response :success

    details_div = assert_select('#geobox-search-panel')
    assert_nil details_div.attribute('open')
  end

  test 'index shows geodistance form, closed by default' do
    get '/'
    assert_response :success

    details_div = assert_select('#geobox-search-panel')
    assert_nil details_div.attribute('open')
  end

  test 'geobox form is open with URL parameter' do
    get '/?geobox=true'
    assert_response :success
    assert_select('#geobox-search-panel').attribute('open')
  end

  test 'geodistance form is open with URL parameter' do
    get '/?geodistance=true'
    assert_response :success
    assert_select('#geodistance-search-panel').attribute('open')
  end

  test 'all geobox fields are required when form is open' do
    get '/?geobox=true'
    assert_response :success
    assert_select('#geobox-search-panel').attribute('open')
    assert_select('#geobox-search-panel input') do |input|
      assert_select '[required]', count: 4
    end
  end

  test 'all geodistance fields are required when form is open' do
    get '/?geodistance=true'
    assert_response :success
    assert_select('#geodistance-search-panel').attribute('open')
    assert_select('#geodistance-search-panel input') do |input|
      assert_select '[required]', count: 3
    end
  end

  test 'geobox and geodistance forms do not appear if GDT feature is disabled' do
    @test_strategy.switch!(:gdt, false)
    get '/'
    assert_response :success
    assert_select '#geobox-search-panel', count: 0
    assert_select '#geodistance-search-panel', count: 0
  end

  test 'can query geobox' do
    VCR.use_cassette('geobox',
                      allow_playback_repeats: true,
                      match_requests_on: %i[method uri body]) do
      query = {
        geobox: 'true',
        geoboxMinLongitude: 40.5,
        geoboxMinLatitude: 60.0,
        geoboxMaxLongitude: 78.2,
        geoboxMaxLatitude: 80.0
      }.to_query
      get "/results?#{query}"
      assert_response :success
      assert_nil flash[:error]
    end
  end

  test 'can query geodistance' do
    VCR.use_cassette('geodistance',
                      allow_playback_repeats: true,
                      match_requests_on: %i[method uri body]) do
      query = {
        geodistance: 'true',
        geodistanceLatitude: 36.1,
        geodistanceLongitude: 62.6,
        geodistanceDistance: '50mi'
      }.to_query
      get "/results?#{query}"
      assert_response :success
      assert_nil flash[:error]
    end
  end

  test 'both geospatial fields can be queried at once' do
    VCR.use_cassette('geobox and geodistance',
                      allow_playback_repeats: true,
                      match_requests_on: %i[method uri body]) do
      query = {
        geobox: 'true',
        geodistance: 'true',
        geoboxMinLongitude: 40.5,
        geoboxMinLatitude: 60.0,
        geoboxMaxLongitude: 78.2,
        geoboxMaxLatitude: 80.0,
        geodistanceLatitude: 36.1,
        geodistanceLongitude: 62.6,
        geodistanceDistance: '50mi'
      }.to_query
      get "/results?#{query}"
      assert_response :success
      assert_nil flash[:error]
    end
  end

  test 'geo forms are open on results page with URL parameter' do
    VCR.use_cassette('geobox and geodistance',
                      allow_playback_repeats: true,
                      match_requests_on: %i[method uri body]) do
      query = {
        geobox: 'true',
        geodistance: 'true',
        geoboxMinLongitude: 40.5,
        geoboxMinLatitude: 60.0,
        geoboxMaxLongitude: 78.2,
        geoboxMaxLatitude: 80.0,
        geodistanceLatitude: 36.1,
        geodistanceLongitude: 62.6,
        geodistanceDistance: '50mi'
      }.to_query
      get "/results?#{query}"
      assert_response :success
      assert_nil flash[:error]

      assert_select('#geobox-search-panel').attribute('open')
      assert_select('#geodistance-search-panel').attribute('open')
    end
  end

  test 'coordinates can include decimals or not' do
    VCR.use_cassette('geobox and geodistance many decimals',
                      allow_playback_repeats: true,
                      match_requests_on: %i[method uri body]) do
      query = {
        geobox: 'true',
        geodistance: 'true',
        geoboxMinLongitude: 40.518235,
        geoboxMinLatitude: 60.082199,
        geoboxMaxLongitude: 78.224321,
        geoboxMaxLatitude: 80.017501,
        geodistanceLatitude: 36.100617,
        geodistanceLongitude: 62.600002,
        geodistanceDistance: '50mi'
      }.to_query
      get "/results?#{query}"
      assert_response :success
      assert_nil flash[:error]

      assert_select('#geobox-search-panel').attribute('open')
      assert_select('#geodistance-search-panel').attribute('open')
    end

    VCR.use_cassette('geobox and geodistance no decimals',
                      allow_playback_repeats: true,
                      match_requests_on: %i[method uri body]) do
      query = {
        geobox: 'true',
        geodistance: 'true',
        geoboxMinLongitude: 40,
        geoboxMinLatitude: 60,
        geoboxMaxLongitude: 78,
        geoboxMaxLatitude: 80,
        geodistanceLatitude: 36,
        geodistanceLongitude: 62,
        geodistanceDistance: '50mi'
      }.to_query
      get "/results?#{query}"
      assert_response :success
      assert_nil flash[:error]

      assert_select('#geobox-search-panel').attribute('open')
      assert_select('#geodistance-search-panel').attribute('open')
    end
  end

  test 'geospatial arguments retain values in search form with correct data types' do
    VCR.use_cassette('geobox and geodistance',
                      allow_playback_repeats: true,
                      match_requests_on: %i[method uri body]) do
      query = {
        geobox: 'true',
        geodistance: 'true',
        geoboxMinLongitude: 40.5,
        geoboxMinLatitude: 60.0,
        geoboxMaxLongitude: 78.2,
        geoboxMaxLatitude: 80.0,
        geodistanceLatitude: 36.1,
        geodistanceLongitude: 62.6,
        geodistanceDistance: '50mi' 
      }.to_query
      get "/results?#{query}"
      assert_response :success
      assert_nil flash[:error]

      assert_select 'input#geobox-minLongitude', value: 40.5
      assert_select 'input#geobox-minLatitude', value: 60.0
      assert_select 'input#geobox-maxLongitude', value: 78.2
      assert_select 'input#geobox-maxLatitude', value: 80.0
      assert_select 'input#geodistance-latitude', value: 36.1
      assert_select 'input#geodistance-longitude', value: 62.6
      assert_select 'input#geodistance-distance', value: '50mi'
    end
  end

  test 'geospatial search can combine with basic and advanced inputs' do
    VCR.use_cassette('geo all',
                      allow_playback_repeats: true,
                      match_requests_on: %i[method uri body]) do
      query = {
        q: 'hi',
        title: 'hey',
        citation: 'hello',
        geobox: 'true',
        geodistance: 'true',
        geoboxMinLongitude: 40.5,
        geoboxMinLatitude: 60.0,
        geoboxMaxLongitude: 78.2,
        geoboxMaxLatitude: 80.0,
        geodistanceLatitude: 36.1,
        geodistanceLongitude: 62.6,
        geodistanceDistance: '50mi' 
      }.to_query
      get "/results?#{query}"
      assert_response :success
      assert_nil flash[:error]
    end
  end

  test 'geobox arguments are non-nullable' do
    query = {
      geobox: 'true'
    }.to_query
    get "/results?#{query}"
    assert_response :redirect
    assert_equal flash[:error], "All bounding box fields are required."
  end

  test 'geodistance arguments are non-nullable' do
    query = {
      geodistance: 'true'
    }.to_query
    get "/results?#{query}"
    assert_response :redirect
    assert_equal flash[:error], "All geospatial distance fields are required."
  end

  test 'geobox param is required for geobox search' do
    query = {
      geoboxMinLongitude: 40.5,
      geoboxMinLatitude: 60.0,
      geoboxMaxLongitude: 78.2,
      geoboxMaxLatitude: 80.0
    }.to_query
    get "/results?#{query}"
    assert_response :redirect
    assert_equal flash[:error], "A search term is required."
  end

  test 'geodistance param is required for geobox search' do
    query = {
      geodistanceLatitude: 36.1,
      geodistanceLongitude: 62.6,
      geodistanceDistance: '50mi' 
    }.to_query
    get "/results?#{query}"
    assert_response :redirect
    assert_equal flash[:error], "A search term is required."
  end

  test 'geobox lat cannot fall below lower limit' do
    low_query = {
      geobox: 'true',
      geoboxMinLongitude: -170.0,
      geoboxMinLatitude: -90.000001,
      geoboxMaxLongitude: -180.0,
      geoboxMaxLatitude: -42
    }.to_query
    get "/results?#{low_query}"
    assert_response :redirect
    assert_equal flash[:error], "Latitude must be between -90.0 and 90.0, and longitude must be -180.0 and 180.0."
  end

  test 'geobox long cannot fall below lower limit' do
    low_query = {
      geobox: 'true',
      geoboxMinLongitude: -180.000001,
      geoboxMinLatitude: -90.0,
      geoboxMaxLongitude: -180.0,
      geoboxMaxLatitude: -42
    }.to_query
    get "/results?#{low_query}"
    assert_response :redirect
    assert_equal flash[:error], "Latitude must be between -90.0 and 90.0, and longitude must be -180.0 and 180.0."
  end

  test 'geobox lat/long cannot exceed upper limit' do
    high_query = {
      geobox: 'true',
      geoboxMinLongitude: 180.000001,
      geoboxMinLatitude: 42,
      geoboxMaxLongitude: 180.0,
      geoboxMaxLatitude: 90.0
    }.to_query
    get "/results?#{high_query}"
    assert_response :redirect
    assert_equal flash[:error], "Latitude must be between -90.0 and 90.0, and longitude must be -180.0 and 180.0."
  end

  test 'geobox does not error with minimum lat value' do
    VCR.use_cassette('geobox min lat range limit',
                      allow_playback_repeats: true,
                      match_requests_on: %i[method uri body]) do
      acceptable_query = {
        geobox: 'true',
        geoboxMinLongitude: -45.0,
        geoboxMinLatitude: -90.0,
        geoboxMaxLongitude: -23.997,
        geoboxMaxLatitude: -40.024
      }.to_query
      get "/results?#{acceptable_query}"
      assert_response :success
      assert_nil flash[:error]
    end
  end

  test 'geobox does not error with minimum long value' do
    VCR.use_cassette('geobox min long range limit',
                      allow_playback_repeats: true,
                      match_requests_on: %i[method uri body]) do
      acceptable_query = {
        geobox: 'true',
        geoboxMinLongitude: -180.0,
        geoboxMinLatitude: -45.23,
        geoboxMaxLongitude: -120.36,
        geoboxMaxLatitude: -40.024
      }.to_query
      get "/results?#{acceptable_query}"
      assert_response :success
      assert_nil flash[:error]
    end
  end

  test 'geobox does not error with maximum lat value' do
    VCR.use_cassette('geobox max lat range limit',
                      allow_playback_repeats: true,
                      match_requests_on: %i[method uri body]) do
      acceptable_query = {
        geobox: 'true',
        geoboxMinLongitude: 45.0,
        geoboxMinLatitude: 40.024,
        geoboxMaxLongitude: 23.997,
        geoboxMaxLatitude: 90.0
      }.to_query
      get "/results?#{acceptable_query}"
      assert_response :success
      assert_nil flash[:error]
    end
  end

  test 'geobox does not error with maximum long value' do
    VCR.use_cassette('geobox max long range limit',
                      allow_playback_repeats: true,
                      match_requests_on: %i[method uri body]) do
      acceptable_query = {
        geobox: 'true',
        geoboxMinLongitude: 45.0,
        geoboxMinLatitude: 40.024,
        geoboxMaxLongitude: 180.0,
        geoboxMaxLatitude: 50.024
      }.to_query
      get "/results?#{acceptable_query}"
      assert_response :success
      assert_nil flash[:error]
    end
  end

  test 'geobox minLat must be less than maxLat' do
    bad_values = {
      geobox: 'true',
      geoboxMinLongitude: 100.0,
      geoboxMinLatitude: 80.0,
      geoboxMaxLongitude: 29.6,
      geoboxMaxLatitude: 56.9
    }.to_query
    get "/results?#{bad_values}"
    assert_response :redirect
    assert_equal flash[:error], "Maximum latitude cannot exceed minimum latitude."
  end

  test 'geodistance lat cannot fall below lower limit' do
    low_query = {
      geodistance: 'true',
      geodistanceLatitude: -90.000001,
      geodistanceLongitude: -180.0,
      geodistanceDistance: '50mi' 
    }.to_query
    get "/results?#{low_query}"
    assert_response :redirect
    assert_equal flash[:error], "Latitude must be between -90.0 and 90.0, and longitude must be -180.0 and 180.0."
  end

  test 'geodistance long cannot fall below lower limit' do
    low_query = {
      geodistance: 'true',
      geodistanceLatitude: -90.0,
      geodistanceLongitude: -180.000001,
      geodistanceDistance: '50mi' 
    }.to_query
    get "/results?#{low_query}"
    assert_response :redirect
    assert_equal flash[:error], "Latitude must be between -90.0 and 90.0, and longitude must be -180.0 and 180.0."
  end

  test 'geodistance lat cannot exceed upper limit' do
    high_query = {
      geodistance: 'true',
      geodistanceLatitude: 90.000001,
      geodistanceLongitude: 180.0,
      geodistanceDistance: '50mi' 
    }.to_query
    get "/results?#{high_query}"
    assert_response :redirect
    assert_equal flash[:error], "Latitude must be between -90.0 and 90.0, and longitude must be -180.0 and 180.0."
  end

  test 'geodistance long cannot exceed upper limit' do
    high_query = {
      geodistance: 'true',
      geodistanceLatitude: 90.0,
      geodistanceLongitude: 180.000001,
      geodistanceDistance: '50mi' 
    }.to_query
    get "/results?#{high_query}"
    assert_response :redirect
    assert_equal flash[:error], "Latitude must be between -90.0 and 90.0, and longitude must be -180.0 and 180.0."
  end

  test 'geodistance does not error with minimum lat value' do
    VCR.use_cassette('geodistance min lat range limit',
                      allow_playback_repeats: true,
                      match_requests_on: %i[method uri body]) do
      acceptable_query = {
        geodistance: 'true',
        geodistanceLatitude: -90.0,
        geodistanceLongitude: -43.33,
        geodistanceDistance: '50mi' 
      }.to_query
      get "/results?#{acceptable_query}"
      assert_response :success
      assert_nil flash[:error]
    end
  end

  test 'geodistance does not error with minimum long value' do
    VCR.use_cassette('geodistance min long range limit',
                      allow_playback_repeats: true,
                      match_requests_on: %i[method uri body]) do
      acceptable_query = {
        geodistance: 'true',
        geodistanceLatitude: -21.1724,
        geodistanceLongitude: -180.0,
        geodistanceDistance: '50mi' 
      }.to_query
      get "/results?#{acceptable_query}"
      assert_response :success
      assert_nil flash[:error]
    end
  end

  test 'geodistance does not error with maximum lat value' do
    VCR.use_cassette('geodistance max lat range limit',
                      allow_playback_repeats: true,
                      match_requests_on: %i[method uri body]) do
      acceptable_query = {
        geodistance: 'true',
        geodistanceLatitude: 90.0,
        geodistanceLongitude: -43.33,
        geodistanceDistance: '50mi' 
      }.to_query
      get "/results?#{acceptable_query}"
      assert_response :success
      assert_nil flash[:error]
    end
  end

  test 'geodistance does not error with maximum long value' do
    VCR.use_cassette('geodistance max long range limit',
                      allow_playback_repeats: true,
                      match_requests_on: %i[method uri body]) do
      acceptable_query = {
        geodistance: 'true',
        geodistanceLatitude: -21.1724,
        geodistanceLongitude: 180.0,
        geodistanceDistance: '50mi' 
      }.to_query
      get "/results?#{acceptable_query}"
      assert_response :success
      assert_nil flash[:error]
    end
  end    

  test 'geodistance cannot be negative' do
    zero_distance = {
      geodistance: 'true',
      geodistanceLatitude: 90.0,
      geodistanceLongitude: 180.0,
      geodistanceDistance: '-50mi' 
    }.to_query
    get "/results?#{zero_distance}"
    assert_response :redirect
    assert_equal flash[:error], "Distance must include an integer greater than 0."
  end

  test 'geodistance cannot be 0' do
    negative_distance = {
      geodistance: 'true',
      geodistanceLatitude: 90.0,
      geodistanceLongitude: 180.0,
      geodistanceDistance: '0mi' 
    }.to_query
    get "/results?#{negative_distance}"
    assert_response :redirect
    assert_equal flash[:error], "Distance must include an integer greater than 0."
  end

  test 'geodistance can contain units or not (default is meters)' do
    VCR.use_cassette('geodistance units',
                      allow_playback_repeats: true,
                      match_requests_on: %i[method uri body]) do
      acceptable_query = {
        geodistance: 'true',
        geodistanceLatitude: -21.1724,
        geodistanceLongitude: 76.021,
        geodistanceDistance: '50mi'
      }.to_query
      get "/results?#{acceptable_query}"
      assert_response :success
      assert_nil flash[:error]
    end

    VCR.use_cassette('geodistance no units',
                      allow_playback_repeats: true,
                      match_requests_on: %i[method uri body]) do
      another_acceptable_query = {
        geodistance: 'true',
        geodistanceLatitude: -21.1724,
        geodistanceLongitude: 76.021,
        geodistanceDistance: '50'
      }.to_query
      get "/results?#{another_acceptable_query}"
      assert_response :success
      assert_nil flash[:error]
    end
  end

  test 'geodistance units must be valid' do
    bad_units = {
      geodistance: 'true',
      geodistanceLatitude: -21.1724,
      geodistanceLongitude: 76.021,
      geodistanceDistance: '50foo'
    }.to_query
    get "/results?#{bad_units}"
    assert_response :redirect
    assert_equal flash[:error], "Distance units must be one of the following: mi, km, yd, ft, in, m, cm, mm, NM/nmi"
  end

  test 'view full record link appears as expected for GDT records' do
    VCR.use_cassette('geobox',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      query = {
        geobox: 'true',
        geoboxMinLongitude: 40.5,
        geoboxMinLatitude: 60.0,
        geoboxMaxLongitude: 78.2,
        geoboxMaxLatitude: 80.0
      }.to_query
      get "/results?#{query}"
      assert_response :success

      record_id = controller.view_assigns['results'].first['timdexRecordId']
      assert_select '.result-record a', href: '/record/#{record_id}', text: 'View full record'
    end
  end

  test 'geo sources are relabeled when GDT feature is enabled' do
    VCR.use_cassette('geobox',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      query = {
        geobox: 'true',
        geoboxMinLongitude: 40.5,
        geoboxMinLatitude: 60.0,
        geoboxMaxLongitude: 78.2,
        geoboxMaxLatitude: 80.0
      }.to_query
      get "/results?#{query}"
      assert_response :success

      # The original source names do not appear in the UI.
      assert_select 'span.name', text: 'mit gis resources', count: 0
      assert_select 'span.name', text: 'opengeometadata gis resources', count: 0

      # The friendly source names do appear instead.
      assert_select 'span.name', text: 'MIT'
      assert_select 'span.name', text: 'Non-MIT institutions'
    end
  end
end
