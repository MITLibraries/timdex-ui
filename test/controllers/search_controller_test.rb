require 'test_helper'

class SearchControllerTest < ActionDispatch::IntegrationTest
  test 'index shows basic search form by default' do
    get '/'
    assert_response :success

    assert_select 'form#basic-search', { count: 1 }

    details_div = assert_select('details#advanced-search-panel')
    assert_nil details_div.attribute('open')
  end

  test 'index shows advanced search form with URL parameter' do
    get '/?advanced=true'

    assert_response :success

    details_div = assert_select('details#advanced-search-panel')
    assert details_div.attribute('open')
  end

  test 'advanced search form appears on results page with URL parameter' do
    VCR.use_cassette('advanced',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?advanced=true'

      assert_response :success

      details_div = assert_select('details#advanced-search-panel')
      assert details_div.attribute('open')
    end
  end

  test 'search form includes a number of fields' do
    get '/'

    # Please note that this test confirms fields in the DOM - but not whether
    # they are visible. Fields in a hidden details panel are still in the DOM,
    # but not visible or reachable via keyboard interaction.
    assert_select 'input#basic-search-main', { count: 1 }
    assert_select 'input#advanced-citation', { count: 1 }
    assert_select 'input#advanced-contributors', { count: 1 }
    assert_select 'input#advanced-fundingInformation', { count: 1 }
    assert_select 'input#advanced-identifiers', { count: 1 }
    assert_select 'input#advanced-locations', { count: 1 }
    assert_select 'input#advanced-subjects', { count: 1 }
    assert_select 'input#advanced-title', { count: 1 }
    assert_select 'input.source', { minimum: 3 }
  end

  test 'advanced search source checkboxes can be controlled by env' do
    get '/'
    assert_select 'input.source', { minimum: 3 }

    ClimateControl.modify TIMDEX_SOURCES: 'HIGHLANDER' do
      get '/'
      assert_select 'input.source', { count: 1 }
    end

    ClimateControl.modify TIMDEX_SOURCES: 'SITH,LORDS' do
      get '/'
      assert_select 'input.source', { count: 2 }
    end
  end

  test 'results with no query redirects with info' do
    get '/results'
    assert_response :redirect
    assert_equal 'A search term is required.', flash[:error]
  end

  test 'results with blank query redirects with info' do
    get '/results?q='
    assert_response :redirect
    assert_equal 'A search term is required.', flash[:error]
  end

  test 'results with blank-ish query redirects with info' do
    get '/results?q=%20'
    assert_response :redirect
    assert_equal 'A search term is required.', flash[:error]
  end

  test 'results with valid query displays the query' do
    VCR.use_cassette('timdex hallo',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=hallo'
      assert_response :success
      assert_nil flash[:error]

      assert_select 'input[value=?]', 'hallo'
    end
  end

  test 'results with valid query shows search form' do
    VCR.use_cassette('timdex hallo',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=hallo'
      assert_response :success

      assert_select 'form#basic-search', { count: 1 }
    end
  end

  test 'results with valid query populates search form with query' do
    VCR.use_cassette('data basic controller',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=data'
      assert_response :success

      assert_select '#basic-search-main[value=data]'
    end
  end

  test 'results with valid query has div for hints' do
    VCR.use_cassette('data basic controller',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=data'
      assert_response :success

      assert_select '#hint'
    end
  end

  test 'results with valid query has div for filters which is populated' do
    VCR.use_cassette('data basic controller',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=data'
      assert_response :success
      assert_select '#filters'
      assert_select '#filters .category .filter-label', { minimum: 1 }
    end
  end

  test 'results with valid query has div for pagination' do
    VCR.use_cassette('data basic controller',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=data'
      assert_response :success

      assert_select '#pagination'
    end
  end

  test 'results with valid query has div for results which is populated' do
    VCR.use_cassette('data basic controller',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=data'
      assert_response :success
      assert_select '#results'
      assert_select '#results .record-title', { minimum: 1 }
    end
  end

  test 'results with valid query include links' do
    VCR.use_cassette('data basic controller',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=data'
      assert_select '#results .record-title a' do |value|
        refute_nil(value.xpath('./@href').text)
      end
    end
  end

  test 'results with valid query have query highlights' do
    VCR.use_cassette('data basic controller',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=data'
      assert_response :success
      assert_select '#results .result-highlights ul li', { minimum: 1 }
    end
  end

  test 'highlights partial is not rendered for results with no relevant highlights' do
    VCR.use_cassette('advanced title data',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?title=data&advanced=true'
      assert_response :success

      # We shouldn't see any highlighted terms because all of the matches will be on title, which is included in
      # SearchHelper#displayed_fields
      assert_select '#results .result-highlights ul li', { count: 0 }
    end
  end

  test 'searches with zero results are handled gracefully' do
    VCR.use_cassette('timdex no results',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=asdfiouwenlasd'
      assert_response :success

      # Result list contents state "no results"
      assert_select '#results'
      assert_select '#results', { count: 1 }
      assert_select '#results p', 'No results found for your search'

      # Filter sidebar is not shown
      assert_select '#filters', { count: 0 }

      # Filters are not shown
      assert_select '#filters .category h3', { count: 0 }

      # Pagination is not shown
      assert_select '#pagination', { count: 0 }
    end
  end

  test 'searches with ISSN display issn fact card' do
    VCR.use_cassette('timdex 1234-5678',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=1234-5678'
      assert_response :success

      actual_div = assert_select('div[data-content-loader-url-value]')
      assert_equal '/issn?issn=1234-5678',
                   actual_div.attribute('data-content-loader-url-value').value
    end
  end

  test 'searches with ISBN insert isbn dom element' do
    VCR.use_cassette('timdex 9781857988536',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=9781857988536'
      assert_response :success

      actual_div = assert_select('div[data-content-loader-url-value]')
      assert_equal '/isbn?isbn=9781857988536',
                   actual_div.attribute('data-content-loader-url-value').value
    end
  end

  test 'searches with DOI insert doi dom element' do
    VCR.use_cassette('timdex 10.1038.nphys1170 ',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=10.1038/nphys1170 '
      assert_response :success

      actual_div = assert_select('div[data-content-loader-url-value]')
      assert_equal '/doi?doi=10.1038%2Fnphys1170',
                   actual_div.attribute('data-content-loader-url-value').value
    end
  end

  test 'searches with pmid insert pmid dom element' do
    VCR.use_cassette('timdex PMID 35649707',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=PMID: 35649707'
      assert_response :success

      actual_div = assert_select('div[data-content-loader-url-value]')
      assert_equal '/pmid?pmid=PMID%3A+35649707',
                   actual_div.attribute('data-content-loader-url-value').value
    end
  end

  # Advanced search behavior
  test 'advanced search by keyword' do
    skip("We no longer display a list of search terms in the UI; leaving this in in case we decide to reintroduce" \
         "that feature soon.")
    VCR.use_cassette('advanced keyword asdf',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=asdf&advanced=true'
      assert_response :success
      assert_nil flash[:error]

      assert_select 'li', 'Keyword anywhere: asdf'
    end
  end

  test 'can search an advanced field without a keyword search' do
    # note, this confirms we only validate param[:q] is present for basic searches
    VCR.use_cassette('advanced citation asdf',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?citation=asdf&advanced=true'
      assert_response :success
      assert_nil flash[:error]
    end
  end

  test 'advanced search can accept values from all fields' do
    skip("We no longer display a list of search terms in the UI; leaving this in in case we decide to reintroduce" \
         "that feature soon.")
    VCR.use_cassette('advanced all',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      query = {
        q: 'data',
        citation: 'citation',
        contributors: 'contribs',
        fundingInformation: 'fund',
        identifiers: 'ids',
        locations: 'locs',
        subjects: 'subs',
        title: 'title',
        source: 'sauce',
        advanced: 'true'
      }.to_query
      get "/results?#{query}"
      assert_response :success
      assert_nil flash[:error]

      assert_select 'li', 'Keyword anywhere: data'
      assert_select 'li', 'Citation: citation'
      assert_select 'li', 'Contributors: contribs'
      assert_select 'li', 'Funders: fund'
      assert_select 'li', 'Identifiers: ids'
      assert_select 'li', 'Locations: locs'
      assert_select 'li', 'Subjects: subs'
      assert_select 'li', 'Title: title'
      assert_select 'li', 'Source: sauce'
    end
  end

  test 'advanced search form retains values with spaces' do
    VCR.use_cassette('advanced all spaces',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      query = {
        q: 'some data',
        citation: 'a citation',
        contributors: 'some contribs',
        fundingInformation: 'a fund',
        identifiers: 'some ids',
        locations: 'some locs',
        subjects: 'some subs',
        title: 'a title',
        advanced: 'true'
      }.to_query
      get "/results?#{query}"
      assert_response :success
      assert_nil flash[:error]

      assert_select 'input#basic-search-main', value: 'some data'
      assert_select 'input#advanced-citation', value: 'a citation'
      assert_select 'input#advanced-contributors', value:'some contribs'
      assert_select 'input#advanced-fundingInformation', value: 'a fund'
      assert_select 'input#advanced-identifiers', value: 'some ids'
      assert_select 'input#advanced-locations', value: 'some locs'
      assert_select 'input#advanced-subjects', value: 'some subs'
      assert_select 'input#advanced-title', value: 'a title'
    end
  end

  def source_filter_count(controller)
    controller.view_context.assigns['filters'][:sourceFilter].count
  end

  test 'advanced search can limit to a single source' do
    VCR.use_cassette('advanced source limit to one source',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      query = {
        q: 'data',
        advanced: 'true',
        sourceFilter: ['Woods Hole Open Access Server']
      }.to_query
      get "/results?#{query}"
      assert_response :success
      assert_nil flash[:error]

      assert(source_filter_count(@controller) == 1)
    end
  end

  test 'advanced search defaults to all sources' do
    VCR.use_cassette('advanced source defaults to all',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      query = {
        q: 'data',
        advanced: 'true'
      }.to_query
      get "/results?#{query}"
      assert_response :success
      assert_nil flash[:error]

      # Assumption is we'll have at least 2 RDI sources for the time being
      assert(source_filter_count(@controller) > 2)
    end
  end

  test 'advanced search can limit to multiple sources' do
    VCR.use_cassette('advanced source limit to two sources',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      # NOTE: when regenerating cassettes, if the source data does not have these
      # sources you may need to change the source array below to two sources that are
      # valid in the current available data.
      query = {
        q: 'data',
        advanced: 'true',
        sourceFilter: ['Abdul Latif Jameel Poverty Action Lab Dataverse', 'Woods Hole Open Access Server']
      }.to_query
      get "/results?#{query}"
      assert_response :success
      assert_nil flash[:error]

      assert(source_filter_count(@controller) == 2)
    end
  end

  test 'applications can customize the displayed filters via ENV' do
    VCR.use_cassette('data basic controller',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      # Our standard test ENV does not define ACTIVE_FILTERS, but this confirms
      # the behavior when it is not defined.
      ClimateControl.modify ACTIVE_FILTERS: '' do
        get '/results?q=data'
        assert_response :success
        assert_select '#filters .category .filter-label', { minimum: 1 }
      end

      # Ask for a single filter, get that filter.
      ClimateControl.modify ACTIVE_FILTERS: 'subjects' do
        get '/results?q=data'
        assert_response :success
        assert_select '#filters .category .filter-label', { count: 1 }
        assert_select '#filters .category:first-of-type .filter-label', 'Subject'
      end

      # The order of the terms matter, so now Format should be first.
      ClimateControl.modify ACTIVE_FILTERS: 'format, contentType, source' do
        get '/results?q=data'
        assert_response :success
        assert_select '#filters .category .filter-label', { count: 3 }
        assert_select '#filters .category:first-of-type .filter-label', 'Format'
      end

      # Including extra values does not affect anything - "nonsense" is extraneous.
      ClimateControl.modify ACTIVE_FILTERS: 'contentType, nonsense, source' do
        get '/results?q=data'
        assert_response :success
        assert_select '#filters .category .filter-label', { count: 2 }
        assert_select '#filters .category:first-of-type .filter-label', 'Content type'
      end
    end
  end

  # Geospatial search behavior
  class SearchControllerGeoTest < SearchControllerTest
    def setup
      @test_strategy = Flipflop::FeatureSet.current.test!
      @test_strategy.switch!(:gdt, true)
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
end
