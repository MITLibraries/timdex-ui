require 'test_helper'

class SearchControllerTest < ActionDispatch::IntegrationTest
  # Clearing cache before each test to prevent any cache-related flakiness from threading.
  setup do
    Rails.cache.clear
  end

  def mock_primo_search_success
    # Mock the Primo search components to avoid external API calls (single call)
    sample_doc = {
      api: 'primo',
      title: 'Sample Primo Document Title',
      format: 'Article',
      year: '2025',
      creators: [
        { value: 'Foo Barston', link: nil },
        { value: 'Baz Quxley', link: nil }
      ],
      links: [{ 'kind' => 'full record', 'url' => 'https://example.com/record' }]
    }

    mock_primo = mock('primo_search')
    mock_primo.expects(:search).returns({ 'docs' => [sample_doc], 'info' => { 'total' => 1 } })
    PrimoSearch.expects(:new).returns(mock_primo)

    mock_normalizer = mock('normalizer')
    mock_normalizer.expects(:normalize).returns([sample_doc])
    NormalizePrimoResults.expects(:new).returns(mock_normalizer)
  end

  def mock_primo_search_all_tab
    # Mock the Primo search components for the all tab (multiple calls)
    sample_doc = {
      api: 'primo',
      title: 'Sample Primo Document Title',
      format: 'Article',
      year: '2025',
      creators: [
        { value: 'Foo Barston', link: nil },
        { value: 'Baz Quxley', link: nil }
      ],
      links: [{ 'kind' => 'full record', 'url' => 'https://example.com/record' }]
    }

    mock_primo = mock('primo_search')
    mock_primo.expects(:search).returns({ 'docs' => [sample_doc], 'info' => { 'total' => 1 } }).at_least_once
    PrimoSearch.expects(:new).returns(mock_primo).at_least_once

    mock_normalizer = mock('normalizer')
    mock_normalizer.expects(:normalize).returns([sample_doc]).at_least_once
    NormalizePrimoResults.expects(:new).returns(mock_normalizer).at_least_once
  end

  def mock_primo_search_with_hits(total_hits)
    sample_docs = (1..10).map do |i|
      {
        title: "Sample Primo Document Title #{i}",
        format: 'Article',
        year: '2025',
        creators: [{ value: "Author #{i}", link: nil }],
        links: [{ 'kind' => 'full record', 'url' => "https://example.com/record#{i}" }]
      }
    end

    mock_primo = mock('primo_search')
    mock_primo.expects(:search).returns({
                                          'docs' => sample_docs,
                                          'info' => { 'total' => total_hits }
                                        })
    PrimoSearch.expects(:new).returns(mock_primo)

    mock_normalizer = mock('normalizer')
    mock_normalizer.expects(:normalize).returns(sample_docs)
    NormalizePrimoResults.expects(:new).returns(mock_normalizer)
  end

  def mock_timdex_search_success
    # Mock the TIMDEX GraphQL client to avoid external API calls (single call)
    sample_result = {
      'api' => 'timdex',
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

    TimdexBase::Client.expects(:query).returns(mock_response).at_least_once
  end

  def mock_timdex_search_all_tab
    # Mock the TIMDEX GraphQL client for the all tab (multiple calls)
    sample_result = {
      'api' => 'timdex',
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

    TimdexBase::Client.expects(:query).returns(mock_response).at_least_once
  end

  def mock_timdex_search_with_hits(total_hits)
    sample_results = (1..10).map do |i|
      {
        'title' => "Sample TIMDEX Document Title #{i}",
        'timdexRecordId' => "sample-record-#{i}",
        'contentType' => [{ 'value' => 'Article' }],
        'dates' => [{ 'kind' => 'Publication date', 'value' => '2023' }],
        'contributors' => [{ 'value' => "Creator #{i}", 'kind' => 'Creator' }],
        'sourceLink' => "https://example.com/record#{i}"
      }
    end

    mock_response = mock('timdex_response')
    mock_errors = mock('timdex_errors')
    mock_errors.stubs(:details).returns({})
    mock_errors.stubs(:to_h).returns({})
    mock_response.stubs(:errors).returns(mock_errors)

    mock_data = mock('timdex_data')
    mock_search = mock('timdex_search')
    mock_search.stubs(:to_h).returns({
                                       'hits' => total_hits,
                                       'aggregations' => {},
                                       'records' => sample_results
                                     })
    mock_data.stubs(:search).returns(mock_search)
    mock_data.stubs(:to_h).returns({
                                     'search' => {
                                       'hits' => total_hits,
                                       'aggregations' => {},
                                       'records' => sample_results
                                     }
                                   })
    mock_response.stubs(:data).returns(mock_data)

    TimdexBase::Client.expects(:query).returns(mock_response).at_least_once

    # Mock the results normalization
    normalized_results = sample_results.map { |result| result.merge({ source: 'TIMDEX' }) }
    mock_normalizer = mock('normalizer')
    mock_normalizer.expects(:normalize).returns(normalized_results).at_least_once
    NormalizeTimdexResults.expects(:new).returns(mock_normalizer).at_least_once
  end

  test 'index shows basic search form by default' do
    get '/'
    assert_response :success

    assert_select 'form#search-form', { count: 1 }
    assert_select 'details#advanced-search-panel', count: 0
  end

  test 'index shows advanced search form with URL parameter' do
    skip('Advanced search functionality not implemented in USE UI')

    get '/?advanced=true'
    assert_response :success
    details_div = assert_select('details#advanced-search-panel')
    assert details_div.attribute('open')
  end

  test 'index shows basic search form when GeoData is disabled' do
    # GeoData is disabled by default in test setup
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
    skip('Advanced search functionality not implemented in USE UI')
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

    # Basic search field should always be present
    assert_select 'input#basic-search-main', { count: 1 }
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
    get '/results?q=hallo&tab=primo'
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
    get '/results?q=hallo&tab=primo'
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
    get '/results?q=data&tab=primo'
    assert_response :success

    assert_select '#basic-search-main[value=data]'
  end

  test 'timdex results with valid query populates search form with query' do
    mock_timdex_search_success
    get '/results?q=data&tab=timdex'
    assert_response :success

    assert_select '#basic-search-main[value=data]'
  end

  test 'results page shows basic USE search form when GeoData is disabled' do
    # GeoData is disabled by default in test setup
    mock_primo_search_success
    get '/results?q=test&tab=primo'
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
    get '/results?q=data&tab=primo'
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
    get '/results?q=data&tab=primo'
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
    get '/results?q=data&tab=primo'
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
    # Stub TIMDEX response for this test to avoid VCR cassette mismatches.
    sample_result = {
      'api' => 'timdex',
      'title' => 'Sample TIMDEX Document Title',
      'timdexRecordId' => 'sample-record-123',
      'contentType' => [{ 'value' => 'Article' }],
      'dates' => [{ 'kind' => 'Publication date', 'value' => '2023' }],
      'contributors' => [{ 'value' => 'Foo Barston', 'kind' => 'Creator' }],
      'highlight' => [],
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

    TimdexBase::Client.expects(:query).returns(mock_response).at_least_once

    # Use the TIMDEX tab route to exercise highlighting behavior without running advanced search/VCR
    get '/results?q=data&tab=timdex'
    assert_response :success

    # We shouldn't see any highlighted terms because all of the matches will be on title, which is included in
    # SearchHelper#displayed_fields
    assert_select '#results .result-highlights ul li', { count: 0 }
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
  test 'results defaults to all tab when no tab parameter provided' do
    # Mock both APIs since 'all' tab calls both
    mock_primo_search_all_tab
    mock_timdex_search_all_tab

    get '/results?q=test'
    assert_response :success
    assert_select 'a.tab-link.active[href*="tab=all"]', count: 1
  end

  test 'results respects primo tab parameter' do
    ClimateControl.modify FEATURE_TAB_PRIMO_ALL: 'true' do
      mock_primo_search_success

      get '/results?q=test&tab=primo'
      assert_response :success
      assert_select 'a.tab-link.active[href*="tab=primo"]', count: 1
    end
  end

  test 'results respects timdex all tab parameter' do
    ClimateControl.modify FEATURE_TAB_TIMDEX_ALL: 'true' do
      mock_timdex_search_success

      get '/results?q=test&tab=timdex'
      assert_response :success
      assert_select 'a.tab-link.active[href*="tab=timdex"]', count: 1
    end
  end

  test 'results respects timdex alma tab parameter' do
    ClimateControl.modify FEATURE_TAB_TIMDEX_ALMA: 'true' do
      mock_timdex_search_success

      get '/results?q=test&tab=timdex_alma'
      assert_response :success
      assert_select 'a.tab-link.active[href*="tab=timdex_alma"]', count: 1
    end
  end

  test 'results shows tab navigation when GeoData is disabled' do
    mock_primo_search_success

    get '/results?q=test&tab=primo'
    assert_response :success
    assert_select '.tab-navigation', count: 1
    assert_select 'a[href*="tab=all"]', count: 1
    assert_select 'a[href*="tab=cdi"]', count: 1
    assert_select 'a[href*="tab=alma"]', count: 1
    # assert_select 'a[href*="tab=primo"]', count: 1
    # assert_select 'a[href*="tab=timdex"]', count: 1
    assert_select 'a[href*="tab=aspace"]', count: 1
    assert_select 'a[href*="tab=website"]', count: 1
  end

  test 'results handles primo search errors gracefully' do
    PrimoSearch.expects(:new).raises(StandardError.new('API Error'))

    get '/results?q=test&tab=primo'
    assert_response :success
    assert_select '.alert', count: 1
    assert_select '.alert', text: /API Error/
  end

  test 'results uses simplified search summary for USE app' do
    mock_primo_search_with_hits(10)

    get '/results?q=test&tab=primo'
    assert_response :success
    assert_select '.results-context', text: /10 results/
    assert_select '.results-context-description', count: 1
    assert_select '.results-context-description', text: /From all MIT Libraries sources/
  end

  test 'primo results shows continuation partial when page exceeds API offset limit' do
    get '/results?q=test&tab=primo&page=49'
    assert_response :success
    assert_select '.primo-continuation', count: 1
    assert_select '.primo-continuation h2', text: /Continue your search in Search Our Collections/
    assert_select '.primo-continuation a[href*="primo.exlibrisgroup.com"]', count: 1
  end

  test 'primo results work normally within API offset limit' do
    mock_primo_search_success

    # Page 40 should work (offset = 39 * 20 = 780, which is < 960)
    get '/results?q=test&tab=primo&page=40'
    assert_response :success
    refute_select '.alert'
    assert_select '#results', count: 1
  end

  test 'primo results shows error when results are empty but docs exist' do
    sample_doc = { 'title' => 'Sample' }

    mock_primo = mock('primo_search')
    mock_primo.expects(:search).returns({ 'docs' => [sample_doc], 'total' => 100 })
    PrimoSearch.expects(:new).returns(mock_primo)

    mock_normalizer = mock('normalizer')
    mock_normalizer.expects(:normalize).returns([])
    NormalizePrimoResults.expects(:new).returns(mock_normalizer)

    get '/results?q=test&tab=primo&page=5'
    assert_response :success
    assert_select '.alert', text: /No more results available at this page number/
  end

  test 'primo results shows continuation when both results and docs are empty' do
    mock_primo = mock('primo_search')
    mock_primo.expects(:search).returns({ 'docs' => [], 'total' => 100 })
    PrimoSearch.expects(:new).returns(mock_primo)

    mock_normalizer = mock('normalizer')
    mock_normalizer.expects(:normalize).returns([])
    NormalizePrimoResults.expects(:new).returns(mock_normalizer)

    get '/results?q=test&tab=primo&page=5'
    assert_response :success
    assert_select '.primo-continuation', count: 1
    assert_select '.primo-continuation h2', text: /Continue your search in Search Our Collections/
  end

  test 'primo results shows no results message when search returns no results on first page' do
    mock_primo = mock('primo_search')
    mock_primo.expects(:search).returns({ 'docs' => [], 'total' => 0 })
    PrimoSearch.expects(:new).returns(mock_primo)

    mock_normalizer = mock('normalizer')
    mock_normalizer.expects(:normalize).returns([])
    NormalizePrimoResults.expects(:new).returns(mock_normalizer)

    get '/results?q=nonexistentterm&tab=primo'
    assert_response :success
    assert_select '.no-results', count: 1
    assert_select '.no-results p', text: /No results found for your search/
    refute_select '.primo-continuation'
  end

  test 'timdex results shows no results message when search returns no results on first page' do
    mock_response = mock('timdex_response')
    mock_errors = mock('timdex_errors')
    mock_errors.stubs(:details).returns({})
    mock_response.stubs(:errors).returns(mock_errors)

    mock_data = mock('timdex_data')
    mock_data.stubs(:to_h).returns({
                                     'search' => {
                                       'hits' => 0,
                                       'aggregations' => {},
                                       'records' => []
                                     }
                                   })
    mock_response.stubs(:data).returns(mock_data)

    TimdexBase::Client.expects(:query).returns(mock_response).at_least_once

    get '/results?q=nonexistentterm&tab=timdex'
    assert_response :success
    assert_select '.no-results', count: 1
    assert_select '.no-results p', text: /No results found for your search/
    refute_select '.primo-continuation'
  end

  test 'all tab displays results from both TIMDEX and Primo' do
    mock_primo_search_all_tab
    mock_timdex_search_all_tab

    get '/results?q=test&tab=all'
    assert_response :success

    # Verify that we get results from both sources
    assert_select '.record-title', text: /Sample Primo Document Title/
    assert_select '.record-title', text: /Sample TIMDEX Document Title/
  end

  test 'all tab handles API errors gracefully' do
    # Mock Primo to fail
    PrimoSearch.expects(:new).raises(StandardError.new('Primo API Error'))
    mock_timdex_search_all_tab

    get '/results?q=test&tab=all'
    assert_response :success
    assert_select '.alert', text: /Primo API Error/
  end

  test 'all tab is default when no tab specified' do
    mock_primo_search_all_tab
    mock_timdex_search_success

    get '/results?q=test'
    assert_response :success

    # Should default to 'all' tab
    assert_select '.tab-navigation .tab-link.active', text: 'All'
  end

  test 'all tab shows as active in navigation' do
    mock_primo_search_all_tab
    mock_timdex_search_all_tab

    get '/results?q=test&tab=all'
    assert_response :success

    assert_select '.tab-navigation .tab-link.active', text: 'All'
  end

  test 'all tab shows primo continuation when page exceeds API offset limit' do
    sample_doc = {
      api: 'primo',
      title: 'Sample Primo Document Title',
      format: 'Article',
      year: '2025',
      creators: [
        { value: 'Foo Barston', link: nil },
        { value: 'Baz Quxley', link: nil }
      ],
      links: [{ 'kind' => 'full record', 'url' => 'https://example.com/record' }]
    }
    mock_primo = mock('primo_search')
    mock_primo.expects(:search).returns({ 'docs' => [sample_doc], 'info' => { 'total' => 1 } }).at_least_once
    PrimoSearch.expects(:new).returns(mock_primo).at_least_once
    mock_normalizer = mock('normalizer')
    mock_normalizer.expects(:normalize).returns([sample_doc]).at_least_once
    NormalizePrimoResults.expects(:new).returns(mock_normalizer).at_least_once
    mock_timdex_search_success

    get '/results?q=test&tab=all&page=49'
    assert_response :success

    # Should show primo continuation partial
    assert_select '.primo-continuation', count: 1
    assert_select '.primo-continuation h2', text: /Continue your search in Search Our Collections/
    assert_select '.primo-continuation a[href*="primo.exlibrisgroup.com"]', count: 1
  end

  test 'all tab pagination displays combined hit counts' do
    sample_docs = (1..10).map do |i|
      {
        title: "Sample Primo Document Title \\#{i}",
        format: 'Article',
        year: '2025',
        creators: [{ value: "Author \\#{i}", link: nil }],
        links: [{ 'kind' => 'full record', 'url' => "https://example.com/record\\#{i}" }]
      }
    end
    mock_primo = mock('primo_search')
    mock_primo.expects(:search).returns({
                                          'docs' => sample_docs,
                                          'info' => { 'total' => 500 }
                                        }).at_least_once
    PrimoSearch.expects(:new).returns(mock_primo).at_least_once
    mock_normalizer = mock('normalizer')
    mock_normalizer.expects(:normalize).returns(sample_docs).at_least_once
    NormalizePrimoResults.expects(:new).returns(mock_normalizer).at_least_once
    mock_timdex_search_with_hits(300)

    get '/results?q=test&tab=all'
    assert_response :success

    # Should show pagination with combined hit counts (500 + 300 = 800)
    assert_select '.pagination-container'
    assert_select '.pagination-container .current', text: /1 - 20 of 800/
  end

  test 'all tab pagination includes next page link when more results available' do
    sample_docs = (1..10).map do |i|
      {
        title: "Sample Primo Document Title \\#{i}",
        format: 'Article',
        year: '2025',
        creators: [{ value: "Author \\#{i}", link: nil }],
        links: [{ 'kind' => 'full record', 'url' => "https://example.com/record\\#{i}" }]
      }
    end
    mock_primo = mock('primo_search')
    mock_primo.expects(:search).returns({
                                          'docs' => sample_docs,
                                          'info' => { 'total' => 500 }
                                        }).at_least_once
    PrimoSearch.expects(:new).returns(mock_primo).at_least_once
    mock_normalizer = mock('normalizer')
    mock_normalizer.expects(:normalize).returns(sample_docs).at_least_once
    NormalizePrimoResults.expects(:new).returns(mock_normalizer).at_least_once
    mock_timdex_search_with_hits(300)

    get '/results?q=test&tab=all'
    assert_response :success

    # Should show next page link when there are more than 20 total results
    assert_select '.pagination-container .next a[href*="page=2"]'
  end

  test 'all tab pagination on page 2 includes previous page link' do
    sample_docs = (1..10).map do |i|
      {
        title: "Sample Primo Document Title \\#{i}",
        format: 'Article',
        year: '2025',
        creators: [{ value: "Author \\#{i}", link: nil }],
        links: [{ 'kind' => 'full record', 'url' => "https://example.com/record\\#{i}" }]
      }
    end
    mock_primo = mock('primo_search')
    mock_primo.expects(:search).returns({
                                          'docs' => sample_docs,
                                          'info' => { 'total' => 500 }
                                        }).at_least_once
    PrimoSearch.expects(:new).returns(mock_primo).at_least_once
    mock_normalizer = mock('normalizer')
    mock_normalizer.expects(:normalize).returns(sample_docs).at_least_once
    NormalizePrimoResults.expects(:new).returns(mock_normalizer).at_least_once
    mock_timdex_search_with_hits(300)

    get '/results?q=test&tab=all&page=2'
    assert_response :success

    # Should show previous page link
    assert_select '.pagination-container .previous a[href*="page=1"]'

    # Should show current range (21-40 for page 2)
    assert_select '.pagination-container .current', text: /21 - 40 of 800/
  end

  test 'merge_results handles unbalanced API responses correctly' do
    # Test case 1: Primo has fewer results than TIMDEX
    paginator = MergedSearchPaginator.new(primo_total: 3, timdex_total: 5, current_page: 1, per_page: 8)
    primo_results = %w[P1 P2 P3]
    timdex_results = %w[T1 T2 T3 T4 T5]
    merged = paginator.merge_results(primo_results, timdex_results)
    expected = %w[P1 T1 P2 T2 P3 T3 T4 T5]
    assert_equal expected, merged

    # Test case 2: TIMDEX has fewer results than Primo
    paginator = MergedSearchPaginator.new(primo_total: 5, timdex_total: 3, current_page: 1, per_page: 8)
    primo_results = %w[P1 P2 P3 P4 P5]
    timdex_results = %w[T1 T2 T3]
    merged = paginator.merge_results(primo_results, timdex_results)
    expected = %w[P1 T1 P2 T2 P3 T3 P4 P5]
    assert_equal expected, merged

    # Test case 3: Results exceed per_page limit (default 20)
    paginator = MergedSearchPaginator.new(primo_total: 15, timdex_total: 15, current_page: 1, per_page: 20)
    primo_results = (1..15).map { |i| "P#{i}" }
    timdex_results = (1..15).map { |i| "T#{i}" }
    merged = paginator.merge_results(primo_results, timdex_results)
    assert_equal 20, merged.length
    assert_equal 'P1', merged[0]
    assert_equal 'T1', merged[1]
    assert_equal 'P2', merged[2]
    assert_equal 'T2', merged[3]

    # Test case 4: One array is empty
    paginator = MergedSearchPaginator.new(primo_total: 0, timdex_total: 3, current_page: 1, per_page: 3)
    primo_results = []
    timdex_results = %w[T1 T2 T3]
    merged = paginator.merge_results(primo_results, timdex_results)
    assert_equal %w[T1 T2 T3], merged

    # Test case 5: more than 10 results from a single source can display when appropriate
    paginator = MergedSearchPaginator.new(primo_total: 7, timdex_total: 11, current_page: 1, per_page: 18)
    primo_results = (1..7).map { |i| "P#{i}" }
    timdex_results = (1..11).map { |i| "T#{i}" }
    merged = paginator.merge_results(primo_results, timdex_results)
    expected = %w[P1 T1 P2 T2 P3 T3 P4 T4 P5 T5 P6 T6 P7 T7 T8 T9 T10 T11]
    assert_equal expected, merged
  end
end
