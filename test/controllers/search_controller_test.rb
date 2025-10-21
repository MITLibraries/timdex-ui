require 'test_helper'

class SearchControllerTest < ActionDispatch::IntegrationTest
  def setup
    @test_strategy = Flipflop::FeatureSet.current.test!
    @test_strategy.switch!(:gdt, false)
  end

  def mock_primo_search_success
    # Mock the Primo search components to avoid external API calls
    sample_doc = {
      'title' => 'Sample Primo Document Title',
      'format' => 'Article',
      'year' => '2025',
      'creators' => [
        { value: 'Foo Barston', link: nil },
        { value: 'Baz Quxley', link: nil }
      ],
      'links' => [{ 'kind' => 'full record', 'url' => 'https://example.com/record' }]
    }

    mock_primo = mock('primo_search')
    mock_primo.expects(:search).returns({ 'docs' => [sample_doc], 'total' => 1 })
    PrimoSearch.expects(:new).returns(mock_primo)

    mock_normalizer = mock('normalizer')
    mock_normalizer.expects(:normalize).returns([sample_doc])
    NormalizePrimoResults.expects(:new).returns(mock_normalizer)
  end

  def mock_timdex_search_success
    # Mock the TIMDEX GraphQL client to avoid external API calls
    sample_result = {
      'title' => 'Sample TIMDEX Document Title',
      'timdexRecordId' => 'sample-record-123',
      'contentType' => [{ 'value' => 'Article' }],
      'dates' => [{ 'kind' => 'Publication date', 'value' => '2023' }],
      'contributors' => [{ 'value' => 'Foo Barston', 'kind' => 'Creator' }],
      'highlight' => [
        {
          'matchedField' => 'summary',
          'matchedPhrases' => ['<span>sample</span> document']
        }
      ],
      'sourceLink' => 'https://example.com/record'
    }

    mock_response = mock('timdex_response')
    mock_errors = mock('timdex_errors')
    mock_errors.stubs(:details).returns({})
    mock_errors.stubs(:to_h).returns({})
    mock_response.stubs(:errors).returns(mock_errors)

    mock_data = mock('timdex_data')
    mock_search = mock('timdex_search')
    mock_search.stubs(:to_h).returns({
                                       'hits' => 1,
                                       'aggregations' => {},
                                       'records' => [sample_result]
                                     })
    mock_data.stubs(:search).returns(mock_search)
    mock_data.stubs(:to_h).returns({
                                     'search' => {
                                       'hits' => 1,
                                       'aggregations' => {},
                                       'records' => [sample_result]
                                     }
                                   })
    mock_response.stubs(:data).returns(mock_data)

    TimdexBase::Client.expects(:query).returns(mock_response)
  end

  test 'index shows basic search form by default' do
    get '/'
    assert_response :success

    assert_select 'form#search-form', { count: 1 }
    assert_select 'details#advanced-search-panel', count: 0
  end

  test 'index shows advanced search form with URL parameter' do
    if Flipflop.enabled?(:gdt)
      get '/?advanced=true'
      assert_response :success
      details_div = assert_select('details#advanced-search-panel')
      assert details_div.attribute('open')
    else
      skip('Advanced search functionality not implemented in USE UI')
    end
  end

  test 'index shows basic search form when GDT is disabled' do
    # GDT is disabled by default in test setup
    get '/'
    assert_response :success

    # Should show basic form without geo elements
    assert_select 'form#search-form', { count: 1 }
    assert_select 'form#search-form-geo', { count: 0 }
    assert_select 'details#geobox-search-panel', { count: 0 }
    assert_select 'details#geodistance-search-panel', { count: 0 }
    assert_select 'details#advanced-search-panel', { count: 0 }
  end

  test 'advanced search form appears on results page with URL parameter' do
    if Flipflop.enabled?(:gdt)
      VCR.use_cassette('advanced',
                       allow_playback_repeats: true,
                       match_requests_on: %i[method uri body]) do
        get '/results?advanced=true'
        assert_response :success
        details_div = assert_select('details#advanced-search-panel')
        assert details_div.attribute('open')
      end
    else
      skip('Advanced search functionality not implemented in USE UI')
    end
  end

  test 'search form includes a number of fields' do
    get '/'

    # Basic search field should always be present
    assert_select 'input#basic-search-main', { count: 1 }

    if Flipflop.enabled?(:gdt)
      # Please note that this test confirms fields in the DOM - but not whether
      # they are visible. Fields in a hidden details panel are still in the DOM,
      # but not visible or reachable via keyboard interaction.
      assert_select 'input#advanced-citation', { count: 1 }
      assert_select 'input#advanced-contributors', { count: 1 }
      assert_select 'input#advanced-fundingInformation', { count: 1 }
      assert_select 'input#advanced-identifiers', { count: 1 }
      assert_select 'input#advanced-locations', { count: 1 }
      assert_select 'input#advanced-subjects', { count: 1 }
      assert_select 'input#advanced-title', { count: 1 }
      assert_select 'input.source', { minimum: 3 }
    end
  end

  test 'advanced search source checkboxes can be controlled by env' do
    skip('Advanced search functionality not implemented in USE UI')
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

  test 'primo results with valid query displays the query' do
    mock_primo_search_success
    get '/results?q=hallo'
    assert_response :success
    assert_nil flash[:error]

    assert_select 'input[value=?]', 'hallo'
  end

  test 'timdex results with valid query displays the query' do
    mock_timdex_search_success
    get '/results?q=hallo&tab=timdex'
    assert_response :success
    assert_nil flash[:error]

    assert_select 'input[value=?]', 'hallo'
  end

  test 'primo results with valid query shows search form' do
    mock_primo_search_success
    get '/results?q=hallo'
    assert_response :success

    assert_select 'form#search-form', { count: 1 }
  end

  test 'timdex results with valid query shows search form' do
    mock_timdex_search_success
    get '/results?q=hallo&tab=timdex'
    assert_response :success

    assert_select 'form#search-form', { count: 1 }
  end

  test 'primo results with valid query populates search form with query' do
    mock_primo_search_success
    get '/results?q=data'
    assert_response :success

    assert_select '#basic-search-main[value=data]'
  end

  test 'timdex results with valid query populates search form with query' do
    mock_timdex_search_success
    get '/results?q=data&tab=timdex'
    assert_response :success

    assert_select '#basic-search-main[value=data]'
  end

  test 'results page shows basic USE search form when GDT is disabled' do
    # GDT is disabled by default in test setup
    mock_primo_search_success
    get '/results?q=test'
    assert_response :success
    assert_select 'form#search-form', { count: 1 }
    assert_select 'form#search-form-geo', { count: 0 }
  end

  test 'results with valid query has div for filters which is populated' do
    skip('Filters not implemented in USE UI')
    VCR.use_cassette('data basic controller',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=data'
      assert_response :success
      assert_select '#filters'
      assert_select '#filters .filter-category .filter-label', { minimum: 1 }
    end
  end

  test 'a filter category lists available filters with names and values' do
    skip('Filters not implemented in USE UI')
    VCR.use_cassette('data basic controller',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=data'
      assert_response :success
      assert_select '.filter-options .category-terms .name', { minimum: 1 }
      assert_select '.filter-options .category-terms .count', { minimum: 1 }
    end
  end

  test 'primo results with valid query has div for pagination' do
    mock_primo_search_success
    get '/results?q=data'
    assert_response :success
    assert_select '#pagination'
  end

  test 'timdex results with valid query has div for pagination' do
    mock_timdex_search_success
    get '/results?q=data&tab=timdex'
    assert_response :success
    assert_select '#pagination'
  end

  test 'primo results with valid query has div for results which is populated' do
    mock_primo_search_success
    get '/results?q=data'
    assert_response :success
    assert_select '#results'
    assert_select '#results .record-title', { minimum: 1 }
  end

  test 'timdex results with valid query has div for results which is populated' do
    mock_timdex_search_success
    get '/results?q=data&tab=timdex'
    assert_response :success
    assert_select '#results'
    assert_select '#results .record-title', { minimum: 1 }
  end

  test 'primo results with valid query include links' do
    mock_primo_search_success
    get '/results?q=data'
    assert_response :success
    assert_select '#results .record-title a'
  end

  test 'timdex results with valid query include links' do
    mock_timdex_search_success
    get '/results?q=data&tab=timdex'
    assert_response :success
    assert_select '#results .record-title a'
  end

  test 'timdex results with valid query have query highlights' do
    mock_timdex_search_success
    get '/results?q=data&tab=timdex'
    assert_response :success
    assert_select '#results .result-highlights ul li', { minimum: 1 }
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
      get '/results?q=asdfiouwenlasd&tab=timdex'
      assert_response :success

      # Result list contents state "no results"
      assert_select '#results'
      assert_select '#results', { count: 1 }
      assert_select '#results .no-results p', 'No results found for your search'

      # Filter sidebar is not shown
      assert_select '#filters', { count: 0 }

      # Filters are not shown
      assert_select '#filters .filter-category h3', { count: 0 }

      # Pagination is not shown
      assert_select '#pagination', { count: 0 }
    end
  end

  test 'TACOS intervention is inserted when TACOS enabled' do
    VCR.use_cassette('tacos',
                     allow_playback_repeats: true) do
      get '/results?q=tacos'

      assert_response :success

      tacos_div = assert_select('div[data-content-loader-url-value].tacos-container')
      assert_equal '/analyze?q=tacos', tacos_div.attribute('data-content-loader-url-value').value
    end
  end

  test 'TACOS intervention not inserted when TACOS not enabled' do
    VCR.use_cassette('tacos',
                     allow_playback_repeats: true) do
      ClimateControl.modify(TACOS_URL: '') do
        get '/results?q=tacos'
      end
      assert_response :success

      assert_select('div[data-content-loader-url-value].tacos-container', 0)
    end
  end

  # Advanced search behavior
  test 'advanced search by keyword' do
    skip('Advanced search not implemented in USE UI')
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
    skip('Advanced search not implemented in USE UI')
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
    skip('Advanced search not implemented in USE UI')
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
      assert_select 'li', 'Funding information: fund'
      assert_select 'li', 'Identifiers: ids'
      assert_select 'li', 'Locations: locs'
      assert_select 'li', 'Subjects: subs'
      assert_select 'li', 'Title: title'
    end
  end

  test 'advanced search form retains values with spaces' do
    skip('Advanced search not implemented in USE UI')
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
      assert_select 'input#advanced-contributors', value: 'some contribs'
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
    skip('Advanced search not implemented in USE UI')
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
    skip('Advanced search not implemented in USE UI')
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
    skip('Advanced search not implemented in USE UI')
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
    skip('Filters not implemented in USE UI')
    VCR.use_cassette('data basic controller',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      # Our standard test ENV does not define ACTIVE_FILTERS, but this confirms
      # the behavior when it is not defined.
      ClimateControl.modify ACTIVE_FILTERS: '' do
        get '/results?q=data'
        assert_response :success
        assert_select '#filters .filter-category .filter-label', { minimum: 1 }
      end

      # Ask for a single filter, get that filter.
      ClimateControl.modify ACTIVE_FILTERS: 'subjects' do
        get '/results?q=data'
        assert_response :success
        assert_select '#filters .filter-category .filter-label', { count: 1 }
        assert_select '#filters .filter-category:first-of-type .filter-label', 'Subject'
      end

      # The order of the terms matter, so now Format should be first.
      ClimateControl.modify ACTIVE_FILTERS: 'format, contentType, source' do
        get '/results?q=data'
        assert_response :success
        assert_select '#filters .filter-category .filter-label', { count: 3 }
        assert_select '#filters .filter-category:first-of-type .filter-label', 'Format'
      end

      # Including extra values does not affect anything - "nonsense" is extraneous.
      ClimateControl.modify ACTIVE_FILTERS: 'contentType, nonsense, source' do
        get '/results?q=data'
        assert_response :success
        assert_select '#filters .filter-category .filter-label', { count: 2 }
        assert_select '#filters .filter-category:first-of-type .filter-label', 'Content type'
      end
    end
  end

  test 'clear all filters button does not appear with zero filters in query' do
    skip('Filters not implemented in USE UI')
    VCR.use_cassette('data basic controller',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=data'
      assert_response :success
      assert_select '.clear-filters', count: 0
    end
  end

  test 'clear all filters button does not appear with one filter in query' do
    skip('Filters not implemented in USE UI')
    VCR.use_cassette('filter one',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      query = {
        q: 'data',
        sourceFilter: ['Woods Hole Open Access Server']
      }.to_query
      get "/results?#{query}"
      assert_response :success
      assert_select '.clear-filters', count: 0
    end
  end

  test 'clear all filters button appears with more than filter in query' do
    skip('Filters not implemented in USE UI')
    VCR.use_cassette('filter multiple',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      query = {
        q: 'data',
        contentTypeFilter: ['dataset'],
        contributorsFilter: ['Woods Hole Open Access Server']
      }.to_query
      get "/results?#{query}"
      assert_response :success
      assert_select '.clear-filters', count: 1
    end
  end

  # Tab functionality tests for USE
  test 'results defaults to primo tab when no tab parameter provided' do
    mock_primo_search_success

    get '/results?q=test'
    assert_response :success
    assert_select 'a.tab-link.active[href*="tab=primo"]', count: 1
  end

  test 'results respects primo tab parameter' do
    mock_primo_search_success

    get '/results?q=test&tab=primo'
    assert_response :success
    assert_select 'a.tab-link.active[href*="tab=primo"]', count: 1
  end

  test 'results respects timdex tab parameter' do
    mock_timdex_search_success

    get '/results?q=test&tab=timdex'
    assert_response :success
    assert_select 'a.tab-link.active[href*="tab=timdex"]', count: 1
  end

  test 'results shows tab navigation when gdt is disabled' do
    mock_primo_search_success

    get '/results?q=test'
    assert_response :success
    assert_select '.tab-navigation', count: 1
    assert_select 'a[href*="tab=primo"]', count: 1
    assert_select 'a[href*="tab=timdex"]', count: 1
  end

  test 'results handles primo search errors gracefully' do
    PrimoSearch.expects(:new).raises(StandardError.new('API Error'))

    get '/results?q=test&tab=primo'
    assert_response :success
    assert_select '.alert', count: 1
    assert_select '.alert', text: /API Error/
  end

  test 'results uses simplified search summary for USE app' do
    mock_primo_search_success

    get '/results?q=test'
    assert_response :success
    assert_select 'aside.search-summary', count: 1
    assert_select 'aside.search-summary', text: /You searched for: test/
  end
end
