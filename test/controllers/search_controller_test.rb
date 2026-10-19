require 'test_helper'

class SearchControllerTest < ActionDispatch::IntegrationTest
  # Clearing cache before each test to prevent any cache-related flakiness from threading.
  setup do
    Rails.cache.clear
  end

  def mock_primo_search_success
    # Mock the Primo search components to avoid external API calls (single call)
    #
    # NOTE: This helper sets expectations for exactly one search invocation
    # (the default `expects` behavior). Some controller flows (the 'all'
    # tab orchestration) may call Primo multiple times. For those tests we
    # use `mock_primo_search_all_tab` which relaxes the expectations with
    # `at_least_once`. Keeping two helpers keeps intent explicit in tests.
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
    mock_normalizer.stubs(:frbr_group_ids).returns([])
    mock_normalizer.expects(:normalize).returns([sample_doc])
    NormalizePrimoResults.expects(:new).returns(mock_normalizer)
  end

  def mock_primo_search_all_tab
    # Mock the Primo search components for the all tab (multiple calls)
    #
    # This helper mirrors `mock_primo_search_success`, but relaxes the
    # expectations to `at_least_once` to allow orchestration paths that may
    # call into Primo multiple times while assembling merged results.
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
    mock_normalizer.stubs(:frbr_group_ids).returns([])
    mock_normalizer.expects(:normalize).returns([sample_doc]).at_least_once
    NormalizePrimoResults.expects(:new).returns(mock_normalizer).at_least_once
  end

  def mock_primo_search_with_hits(total_hits)
    # Use when the test needs to control the simulated Primo hit count, e.g., pagination
    # boundary tests or UI behavior that reacts to total result numbers. Always returns
    # 10 sample documents regardless of `total_hits`; only the reported total varies.
    # For tests that don't care about hit counts, prefer `mock_primo_search_success`.
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
    mock_normalizer.stubs(:frbr_group_ids).returns([])
    mock_normalizer.expects(:normalize).returns(sample_docs)
    NormalizePrimoResults.expects(:new).returns(mock_normalizer)
  end

  def mock_timdex_search_success
    # Use for standard single-tab TIMDEX tests that don't inspect the query variables
    # passed to the GraphQL client. Sets `expects(:query)` without `.with(...)`, so
    # Mocha only verifies the call count, not the arguments.
    #
    # - For the 'all' tab (multiple TIMDEX calls): use `mock_timdex_search_all_tab`.
    # - For tests asserting on query variables (e.g., feature flags): use
    #   `build_timdex_mock_response` and set the expectation with `.with(...)` yourself.
    sample_result = {
      'api' => 'timdex',
      'title' => 'Sample TIMDEX Document Title',
      'timdexRecordId' => 'sample-record-123',
      'contentType' => ['Article'],
      'dates' => [{ 'kind' => 'Publication date', 'value' => '2023' }],
      'contributors' => [{ 'value' => 'Foo Barston', 'kind' => 'Creator' }],
      'highlight' => [
        {
          'matchedField' => 'notes',
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
    # Use for tests exercising the 'all' tab, where `MergedSearchService` may invoke
    # TIMDEX multiple times. Relaxes the expectation to `at_least_once` to accommodate
    # that orchestration. For single-tab TIMDEX tests, prefer `mock_timdex_search_success`
    # so unexpected extra calls cause a failure rather than passing silently.
    sample_result = {
      'api' => 'timdex',
      'title' => 'Sample TIMDEX Document Title',
      'timdexRecordId' => 'sample-record-123',
      'contentType' => ['Article'],
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
    # Use when the test needs to control the simulated TIMDEX hit count, e.g., pagination
    # threshold or no-results-message tests. Always returns 10 sample documents regardless
    # of `total_hits`; only the reported total varies. Unlike the other TIMDEX helpers,
    # this one also mocks `NormalizeTimdexResults` explicitly. For tests that don't care
    # about hit counts, prefer `mock_timdex_search_success`.
    sample_results = (1..10).map do |i|
      {
        'title' => "Sample TIMDEX Document Title #{i}",
        'timdexRecordId' => "sample-record-#{i}",
        'contentType' => ['Article'],
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

  def build_timdex_mock_response
    # Use when a test needs to assert on the variables passed to `TimdexBase::Client.query`
    # (e.g., verifying a feature flag sets the correct query variable). Returns a fully
    # stubbed response object but intentionally does NOT set any expectation on
    # `TimdexBase::Client`. The caller is responsible for setting the expectation:
    #
    #   mock_response = build_timdex_mock_response
    #   TimdexBase::Client.expects(:query).with(TimdexSearch::BaseQuery,
    #     has_entry(:variables, has_entry(:someVar, expected_value))).returns(mock_response)
    #
    # The other TIMDEX helpers (`mock_timdex_search_success`, etc.) set the expectation
    # themselves without `.with(...)`, so they cannot be used when argument assertions
    # are needed — Mocha would end up with two conflicting expectations on the same method.
    sample_result = {
      'api' => 'timdex',
      'title' => 'Sample TIMDEX Document Title',
      'timdexRecordId' => 'sample-record-123',
      'contentType' => ['Article'],
      'dates' => [{ 'kind' => 'Publication date', 'value' => '2023' }],
      'contributors' => [{ 'value' => 'Foo Barston', 'kind' => 'Creator' }],
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
    mock_response
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

  test 'primo results with valid query has load more control' do
    ClimateControl.modify(FEATURE_PAGINATION_LOAD_MORE: 'true') do
      mock_primo_search_success
      get '/results?q=data&tab=primo'
      assert_response :success
      assert_select '#load-more'
    end
  end

  test 'timdex results with valid query has load more control' do
    ClimateControl.modify(FEATURE_PAGINATION_LOAD_MORE: 'true') do
      mock_timdex_search_success
      get '/results?q=data&tab=timdex'
      assert_response :success
      assert_select '#load-more'
    end
  end

  test 'primo full HTML reload of a load-more continuation page shows cumulative results' do
    # Simulates a full (non-Turbo-Stream) page load landing directly on a load-more
    # continuation URL (e.g. after a bot-detection/Turnstile redirect). With load-more
    # enabled, a plain `page=2` request has no prior results in the DOM to append to, so
    # the controller must reconstruct the complete list by re-fetching every earlier page.
    ClimateControl.modify(FEATURE_PAGINATION_LOAD_MORE: 'true', RESULTS_PER_PAGE: '5') do
      page_one_docs = (1..5).map do |i|
        { api: 'primo', title: "Doc #{i}", format: 'Article', year: '2025', creators: [], links: [] }
      end
      page_two_docs = (6..10).map do |i|
        { api: 'primo', title: "Doc #{i}", format: 'Article', year: '2025', creators: [], links: [] }
      end

      mock_primo = mock('primo_search')
      mock_primo.expects(:search).with('data', 5, 0).returns({ 'docs' => page_one_docs, 'info' => { 'total' => 20 } })
      mock_primo.expects(:search).with('data', 5, 5).returns({ 'docs' => page_two_docs, 'info' => { 'total' => 20 } })
      PrimoSearch.expects(:new).returns(mock_primo).twice

      normalizer_one = mock('normalizer_one')
      normalizer_one.expects(:normalize).returns(page_one_docs)
      normalizer_one.stubs(:frbr_group_ids).returns(['page-one-group'])
      normalizer_two = mock('normalizer_two')
      normalizer_two.expects(:normalize).returns(page_two_docs)
      normalizer_two.stubs(:frbr_group_ids).returns(['page-two-group'])
      NormalizePrimoResults.expects(:new).returns(normalizer_one, normalizer_two).twice

      get '/results?q=data&tab=primo'
      assert_response :success
      assert_select '.results-list .result', count: 5

      get '/results?q=data&tab=primo&page=2', headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      assert_response :success

      get '/results?q=data&tab=primo&page=2'
      assert_response :success
      assert_select '.results-list .result', count: 10
      assert_equal %w[page-one-group page-two-group],
                   @controller.send(:search_results_log_payload)[:frbr_group_ids]
    end
  end

  test 'stale Primo reload keeps results visible when hits fit on the first page' do
    ClimateControl.modify(FEATURE_PAGINATION_LOAD_MORE: 'true', RESULTS_PER_PAGE: '5') do
      records = Array.new(3) do |i|
        { api: 'primo', identifier: "p#{i}", title: "Record #{i}", creators: [], links: [] }
      end
      primo = mock('primo_search')
      primo.expects(:search).with('data', 5, 0).once.returns(
        { 'docs' => records, 'info' => { 'total' => 3 } }
      )
      PrimoSearch.expects(:new).once.returns(primo)
      normalizer = mock('normalizer')
      normalizer.expects(:normalize).once.returns(records)
      normalizer.stubs(:frbr_group_ids).returns([])
      NormalizePrimoResults.expects(:new).once.returns(normalizer)

      get '/results?q=data&tab=primo&page=2'

      assert_response :success
      assert_select '#results-list .result', count: 3
      assert_select '.primo-continuation', count: 0
      assert_select '#load-more a', count: 0
      pagination = @controller.instance_variable_get(:@pagination)
      assert_equal 1, pagination[:start]
      assert_equal 3, pagination[:end]
      assert_nil pagination[:next]
    end
  end

  test 'Primo cumulative reload stops after a full final page' do
    ClimateControl.modify(RESULTS_PER_PAGE: '5') do
      controller = SearchController.new
      controller.instance_variable_set(:@enhanced_query, { q: 'test', page: 100 })
      2.times do |page|
        records = Array.new(5) { |i| { identifier: "p#{page * 5 + i}" } }
        controller.expects(:fetch_primo_data).with(offset: page * 5, per_page: 5).once.returns(
          { results: records, hits: 10, errors: nil, show_continuation: false }
        )
      end

      data = controller.send(:fetch_primo_data_through_current_page)

      assert_equal 10, data[:results].length
      assert_equal 6, data[:pagination][:start]
      assert_equal 10, data[:pagination][:end]
      assert_nil data[:pagination][:next]
      assert_not data[:show_continuation]
    end
  end

  %w[primo timdex].each do |tab|
    test "authenticated #{tab} JSON pagination remains independent of browser load more" do
      ClimateControl.modify(FEATURE_PAGINATION_LOAD_MORE: 'true', RESULTS_PER_PAGE: '20',
                            LOAD_MORE_MAX_RESULTS: '45', FORMAT_TOKEN: 'pagination-test-token') do
        [2, 11].each do |page|
          offset = (page - 1) * 20
          records = Array.new(20) { |i| { api: tab, identifier: "r#{offset + i}" } }
          data = { results: records, hits: 100000, errors: nil }
          if tab == 'primo'
            SearchController.any_instance.expects(:cached_primo_data).with(20, offset).once.returns(data)
          else
            SearchController.any_instance.expects(:cached_timdex_data)
                            .with(has_entries('from' => offset.to_s, 'perPage' => 20)).once.returns(data)
          end

          get '/results', params: { q: 'pagination', tab: tab, page: page, format: 'json',
                                    format_token: 'pagination-test-token' }

          assert_response :success
          json = response.parsed_body
          assert_equal records.pluck(:identifier), json['results'].pluck('identifier')
          assert_equal 100000, json['hits']
          assert_nil json['errors']
        end
      end
    end
  end

  test 'timdex cumulative reload stops at the reported final page' do
    ClimateControl.modify(RESULTS_PER_PAGE: '5') do
      controller = SearchController.new
      controller.instance_variable_set(:@enhanced_query, { q: 'test', page: 1000000 })
      controller.expects(:fetch_timdex_data).with(offset: 0, per_page: 5).once.returns(
        { results: [{ identifier: 'only-record' }], hits: 1, errors: nil }
      )

      data = controller.send(:fetch_timdex_data_through_current_page)

      assert_equal ['only-record'], data[:results].pluck(:identifier)
      assert_equal 1, data[:pagination][:start]
      assert_equal 1, data[:pagination][:end]
      assert_nil data[:pagination][:next]
    end
  end

  test 'timdex cumulative reload stops on an empty page despite overreported hits' do
    ClimateControl.modify(RESULTS_PER_PAGE: '5') do
      controller = SearchController.new
      controller.instance_variable_set(:@enhanced_query, { q: 'test', page: 1000000 })
      records = Array.new(5) { |i| { identifier: "t#{i}" } }
      controller.expects(:fetch_timdex_data).with(offset: 0, per_page: 5).once.returns(
        { results: records, hits: 1000, errors: nil }
      )
      controller.expects(:fetch_timdex_data).with(offset: 5, per_page: 5).once.returns(
        { results: [], hits: 1000, errors: nil }
      )

      data = controller.send(:fetch_timdex_data_through_current_page)

      assert_equal records, data[:results]
      assert_equal 5, data[:pagination][:end]
      assert_nil data[:pagination][:next]
    end
  end

  test 'timdex cumulative reload preserves the next page when more results exist' do
    ClimateControl.modify(RESULTS_PER_PAGE: '5') do
      controller = SearchController.new
      controller.instance_variable_set(:@enhanced_query, { q: 'test', page: 2 })
      first_page = Array.new(5) { |i| { identifier: "t#{i}" } }
      second_page = Array.new(5) { |i| { identifier: "t#{i + 5}" } }
      controller.expects(:fetch_timdex_data).with(offset: 0, per_page: 5).once.returns(
        { results: first_page, hits: 20, errors: nil }
      )
      controller.expects(:fetch_timdex_data).with(offset: 5, per_page: 5).once.returns(
        { results: second_page, hits: 20, errors: nil }
      )

      data = controller.send(:fetch_timdex_data_through_current_page)

      assert_equal first_page + second_page, data[:results]
      assert_equal 10, data[:pagination][:end]
      assert_equal 3, data[:pagination][:next]
    end
  end

  test 'large TIMDEX searches cannot exceed the cumulative reconstruction budget' do
    ClimateControl.modify(RESULTS_PER_PAGE: '20', LOAD_MORE_MAX_RESULTS: '200') do
      controller = SearchController.new
      controller.instance_variable_set(:@enhanced_query, { q: 'test', page: 5000 })
      10.times do |page|
        records = Array.new(20) { |i| { identifier: "t#{page * 20 + i}" } }
        controller.expects(:fetch_timdex_data).with(offset: page * 20, per_page: 20).once.returns(
          { results: records, hits: 100000, errors: nil }
        )
      end

      data = controller.send(:fetch_timdex_data_through_current_page)

      assert_equal 200, data[:results].length
      assert_equal 200, data[:pagination][:end]
      assert_nil data[:pagination][:next]
    end
  end

  %w[primo timdex].each do |tab|
    test "#{tab} Turbo Stream page two fetches and appends only page two" do
      ClimateControl.modify(FEATURE_PAGINATION_LOAD_MORE: 'true', RESULTS_PER_PAGE: '5') do
        records = (6..10).map do |i|
          { api: tab, identifier: "record-#{i}", title: "Record #{i}", creators: [], links: [] }
        end

        # Earlier records are already in the browser. Even with a cold cache,
        # this request must never reconstruct or fetch page one (offset zero).
        SearchController.any_instance.expects(:"fetch_#{tab}_data").with(offset: 0, per_page: 5).never
        SearchController.any_instance.expects(:"fetch_#{tab}_data").with(offset: 5, per_page: 5).once.returns(
          { results: records, hits: 20, errors: nil,
            pagination: { end: 10, next: 3, hits: 20 } }
        )

        get "/results?q=stream-page&tab=#{tab}&page=2", headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        assert_response :success
        assert_equal 'text/vnd.turbo-stream.html', response.media_type
        document = Nokogiri::HTML(response.body)
        appends = document.css('turbo-stream[action="append"][target="results-list"]')
        assert_equal 1, appends.length
        assert_equal records.pluck(:identifier), appends.css('.result').map { |node| node['data-record-id'] }
      end
    end

    test "#{tab} load more and oversized reload respect a partial final batch budget" do
      ClimateControl.modify(FEATURE_PAGINATION_LOAD_MORE: 'true', RESULTS_PER_PAGE: '20',
                            LOAD_MORE_MAX_RESULTS: '45') do
        [[0, 20, 1], [20, 20, 2], [40, 5, 2]].each do |offset, count, requests|
          records = Array.new(count) do |i|
            { api: tab, identifier: "r#{offset + i}", title: "Record #{offset + i}", creators: [], links: [] }
          end
          SearchController.any_instance.expects(:"fetch_#{tab}_data").with(offset: offset, per_page: count)
                          .times(requests).returns(
                            { results: records, hits: 100000, errors: nil,
                              pagination: { end: offset + count, next: offset / 20 + 2, hits: 100000 } }
                          )
        end

        get "/results?q=budget&tab=#{tab}&page=2", headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        assert_response :success
        document = Nokogiri::HTML(response.body)
        assert_equal 20, document.css('turbo-stream[action="append"] .result').length
        next_url = document.at_css('#load-more a')['href']

        get next_url, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        assert_response :success
        document = Nokogiri::HTML(response.body)
        assert_equal 5, document.css('turbo-stream[action="append"] .result').length
        assert_nil document.at_css('#load-more a')

        get "/results?q=budget&tab=#{tab}&page=5000"
        assert_response :success
        assert_select '#results-list .result', count: 45
        assert_select '#load-more a', count: 0
      end
    end
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
      'contentType' => ['Article'],
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
      assert_select '#results .no-results h2', 'No results were found'

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

  test 'active filters ignores blank env entries' do
    controller = SearchController.new

    ClimateControl.modify ACTIVE_FILTERS: 'contentType, , source, ' do
      assert_equal %w[contentType source], controller.send(:active_filters)
    end

    ClimateControl.modify ACTIVE_FILTERS: '' do
      assert_empty controller.send(:active_filters)
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

  test 'primo normalization logs only Alma frbr ids on cache misses and hits' do
    record = JSON.parse(File.read(Rails.root.join('test/fixtures/primo/full_record.json')))
    cdi_record = JSON.parse(File.read(Rails.root.join('test/fixtures/primo/cdi_record.json')))
    NormalizePrimoRecord.any_instance.stubs(:normalize).returns({ api: 'primo', identifier: 'test' })
    PrimoSearch.any_instance.expects(:search).once.returns(
      { 'docs' => [record, cdi_record], 'info' => { 'total' => 2 } }
    )

    2.times do
      controller = SearchController.new
      controller.instance_variable_set(:@active_tab, 'primo')
      controller.instance_variable_set(:@enhanced_query, { q: 'frbr-cache-test' })
      controller.send(:fetch_primo_data)

      assert_equal ['12345'], controller.send(:search_results_log_payload)[:frbr_group_ids]
    end
  end

  test 'all tab restores frbr ids from merged load more cache' do
    ClimateControl.modify(FEATURE_PAGINATION_LOAD_MORE: 'true') do
      2.times do |attempt|
        controller = SearchController.new
        controller.instance_variable_set(:@active_tab, 'all')
        controller.instance_variable_set(:@enhanced_query, { q: 'merged-frbr-cache-test' })
        controller.instance_variable_set(:@pagination_load_more_enabled, true)
        controller.stubs(:sanitized_load_count).returns(1)
        controller.stubs(:params).returns(ActionController::Parameters.new)
        if attempt.zero?
          controller.expects(:fetch_primo_data).once.returns(
            { results: [{ api: 'primo', identifier: 'p1', title: 'Test' }],
              hits: 1, frbr_group_ids: ['merged-group'] }
          )
          controller.expects(:fetch_timdex_data).once.returns({ results: [], hits: 0 })
        else
          controller.expects(:fetch_primo_data).never
          controller.expects(:fetch_timdex_data).never
        end

        controller.send(:load_all_results)

        assert_equal ['merged-group'], controller.send(:search_results_log_payload)[:frbr_group_ids]
      end
    end
  end

  test 'primo cache hit avoids external search and normalization' do
    sample_doc = {
      api: 'primo',
      title: 'Cached Primo Document Title',
      format: 'Article',
      year: '2025',
      creators: [{ value: 'Foo Barston', link: nil }],
      identifier: 'primo-record-123',
      links: [{ 'kind' => 'full record', 'url' => 'https://example.com/primo-record' }]
    }

    mock_primo = mock('primo_search')
    mock_primo.expects(:search).once.returns({ 'docs' => [sample_doc], 'info' => { 'total' => 1 } })
    PrimoSearch.expects(:new).once.returns(mock_primo)

    mock_normalizer = mock('normalizer')
    mock_normalizer.expects(:normalize).once.returns([sample_doc])
    mock_normalizer.stubs(:frbr_group_ids).returns(['cached-group'])
    NormalizePrimoResults.expects(:new).once.returns(mock_normalizer)

    2.times do
      get '/results?q=test&tab=primo'
      assert_response :success
      assert_select '.record-title', text: /Cached Primo Document Title/
      assert_equal ['cached-group'], @controller.send(:search_results_log_payload)[:frbr_group_ids]
    end
  end

  test 'primo cache key uses resolved active tab for default all requests' do
    sample_doc = {
      api: 'primo',
      title: 'Cached Default All Primo Document Title',
      format: 'Article',
      year: '2025',
      creators: [{ value: 'Foo Barston', link: nil }],
      identifier: 'default-all-primo-record-123',
      links: [{ 'kind' => 'full record', 'url' => 'https://example.com/default-all-primo-record' }]
    }

    mock_primo = mock('primo_search')
    mock_primo.expects(:search).once.returns({ 'docs' => [sample_doc], 'info' => { 'total' => 1 } })
    PrimoSearch.expects(:new).once.returns(mock_primo)

    mock_normalizer = mock('normalizer')
    mock_normalizer.expects(:normalize).once.returns([sample_doc])
    mock_normalizer.stubs(:frbr_group_ids).returns(['cached-group'])
    NormalizePrimoResults.expects(:new).once.returns(mock_normalizer)

    controller = SearchController.new
    controller.instance_variable_set(:@active_tab, 'all')
    controller.instance_variable_set(:@enhanced_query, { q: 'test' })
    controller.send(:cached_primo_data, 20, 0)

    controller.instance_variable_set(:@enhanced_query, { q: 'test', tab: 'all' })
    cached = controller.send(:cached_primo_data, 20, 0)

    assert_equal [sample_doc], cached[:results]
  end

  test 'primo query uses resolved active tab' do
    controller = SearchController.new
    controller.instance_variable_set(:@active_tab, 'all')
    controller.instance_variable_set(:@enhanced_query, { q: 'test', tab: 'invalid_tab' })

    mock_primo = mock('primo_search')
    mock_primo.expects(:search).with('test', 20, 0).returns({ 'docs' => [], 'info' => { 'total' => 0 } })
    PrimoSearch.expects(:new).with('all').returns(mock_primo)

    controller.send(:query_primo, 20, 0)
  end

  test 'timdex cache hit avoids external search and normalization' do
    normalized_result = {
      api: 'timdex',
      title: 'Cached TIMDEX Document Title',
      format: 'Article',
      year: '2025',
      creators: [{ value: 'Foo Barston', link: nil }],
      identifier: 'timdex-record-123',
      links: [{ 'kind' => 'full record', 'url' => 'https://example.com/timdex-record' }]
    }

    TimdexBase::Client.expects(:query).once.returns(build_timdex_mock_response)

    mock_normalizer = mock('normalizer')
    mock_normalizer.expects(:normalize).once.returns([normalized_result])
    NormalizeTimdexResults.expects(:new).once.returns(mock_normalizer)

    2.times do
      get '/results?q=test&tab=timdex'
      assert_response :success
      assert_select '.record-title', text: /Cached TIMDEX Document Title/
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

  test 'all tab page 1 writes totals to cache' do
    # This integration-level behavior is covered by unit tests on `MergedSearchService`.
    # Here we assert the controller delegates to the service.
    mock_service = mock('merged_service')
    mock_service.expects(:fetch).returns({ results: [], errors: nil, pagination: {}, show_primo_continuation: false })
    MergedSearchService.expects(:new).returns(mock_service)

    get '/results?q=test'
    assert_response :success
  end

  test 'all tab deeper page reads cached totals and avoids summary calls' do
    # This behavior is covered in greater depth by `MergedSearchService` unit tests.
    mock_service = mock('merged_service')
    mock_service.expects(:fetch).with(page: 2,
                                      per_page: 20).returns({ results: [],
                                                              errors: nil, pagination: {}, show_primo_continuation: false })
    MergedSearchService.expects(:new).returns(mock_service)

    get '/results?q=test&page=2'
    assert_response :success
  end

  test 'all tab delegates to MergedSearchService' do
    mock_service = mock('merged_service')
    mock_service.expects(:fetch).returns({ results: [], errors: nil })
    MergedSearchService.expects(:new).returns(mock_service)

    get '/results?q=test&tab=all'
    assert_response :success
  end

  test 'results handles primo search errors gracefully' do
    PrimoSearch.expects(:new).raises(StandardError.new('API Error'))

    get '/results?q=test&tab=primo'
    assert_response :success
    assert_select 'aside[role="alert"]', count: 1
    assert_select 'aside.primo-unavailable h3', text: /Hmm, we seem to be having difficulties/
    assert_select 'aside.primo-unavailable', text: /In the meantime, try searching these tools directly/
    assert_select 'aside.primo-unavailable', text: /MIT's WorldCat: Books and media/
    assert_select 'aside.primo-unavailable', text: /Google Scholar: Articles/
    assert_select 'aside.primo-unavailable', text: /ArchivesSpace: MIT archives/
    assert_select 'aside.primo-unavailable', text: /DSpace@MIT: MIT research/
    assert_select 'aside.primo-unavailable a[href="https://libraries.mit.edu/worldcat"]', text: /MIT's WorldCat/
    assert_select 'aside.primo-unavailable a[href="https://scholar.google.com/"]', text: /Google Scholar/
    assert_select 'aside.primo-unavailable a[href="https://archivesspace.mit.edu/"]', text: /ArchivesSpace/
    assert_select 'aside.primo-unavailable a[href="https://dspace.mit.edu/"]', text: /DSpace@MIT/
    assert_select 'aside.primo-unavailable a[href="https://libraries.mit.edu/ask/"]', text: /Ask Us/
  end

  test 'results uses simplified search summary for USE app' do
    mock_primo_search_with_hits(10)

    get '/results?q=test&tab=primo'
    assert_response :success
    assert_select '.results-context', text: /10 results/
    assert_select '.tab-description', count: 1
    assert_select '.tab-description .wrap-content',
                  text: /Articles, books, chapters, streaming and physical media, and more/
  end

  test 'primo results shows continuation partial when page exceeds API offset limit' do
    get '/results?q=test&tab=primo&page=49'
    assert_response :success
    assert_select '.primo-continuation', count: 1
    assert_select '.primo-continuation h2', text: /You have reached the limit for these search results/
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
    mock_normalizer.stubs(:frbr_group_ids).returns([])
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
    mock_normalizer.stubs(:frbr_group_ids).returns([])
    mock_normalizer.expects(:normalize).returns([])
    NormalizePrimoResults.expects(:new).returns(mock_normalizer)

    get '/results?q=test&tab=primo&page=5'
    assert_response :success
    assert_select '.primo-continuation', count: 1
    assert_select '.primo-continuation h2', text: /You have reached the limit for these search results/
  end

  test 'primo results shows no results message when search returns no results on first page' do
    mock_primo = mock('primo_search')
    mock_primo.expects(:search).returns({ 'docs' => [], 'total' => 0 })
    PrimoSearch.expects(:new).returns(mock_primo)

    mock_normalizer = mock('normalizer')
    mock_normalizer.stubs(:frbr_group_ids).returns([])
    mock_normalizer.expects(:normalize).returns([])
    NormalizePrimoResults.expects(:new).returns(mock_normalizer)

    get '/results?q=nonexistentterm&tab=primo'
    assert_response :success
    assert_select '.no-results', count: 1
    assert_select '.no-results h2', text: /No results were found/
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
    assert_select '.no-results h2', text: /No results were found/
    refute_select '.primo-continuation'
  end

  test 'all tab final capped load more batch appends only unseen records' do
    ClimateControl.modify(FEATURE_PAGINATION_LOAD_MORE: 'true', RESULTS_PER_PAGE: '20',
                          LOAD_MORE_MAX_RESULTS: '45', ALL_TAB_SCORER: 'zipper') do
      records = (1..50).map do |i|
        { api: 'primo', identifier: "p#{i}", title: "Record #{i}", creators: [], links: [] }
      end
      SearchController.any_instance.expects(:fetch_primo_data).once.returns({ results: records, hits: 100 })
      SearchController.any_instance.expects(:fetch_timdex_data).once.returns({ results: [], hits: 0 })

      get '/results?q=capped-batch&tab=all'
      assert_response :success
      seen_ids = css_select('#results-list .result').map { |node| node['data-record-id'] }
      assert_equal 20, seen_ids.length
      next_url = css_select('#load-more a').first['href']

      [20, 5].each do |expected_count|
        get next_url, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        assert_response :success
        document = Nokogiri::HTML(response.body)
        appended_ids = document.css('turbo-stream[action="append"] .result').map { |node| node['data-record-id'] }
        assert_equal expected_count, appended_ids.length
        assert_empty seen_ids & appended_ids
        seen_ids.concat(appended_ids)
        next_url = document.at_css('#load-more a')&.[]('href')
      end

      assert_equal 45, seen_ids.length
      assert_nil next_url

      get '/results?q=capped-batch&tab=all&load_count=45&load_previous_count=40'
      assert_response :success
      assert_select '#results-list .result', count: 45
    end
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
    assert_select 'aside.primo-unavailable h3', text: /Hmm, we seem to be having difficulties/
    assert_select 'aside.primo-unavailable', text: /In the meantime, try searching these tools directly/
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

  test 'all tab shows TIMDEX results and pagination alongside Primo continuation' do
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
    mock_primo.expects(:search).with('test', 1, 0).once.returns(
      { 'docs' => [sample_doc], 'info' => { 'total' => 10000 } }
    )
    PrimoSearch.expects(:new).returns(mock_primo).at_least_once
    mock_normalizer = mock('normalizer')
    mock_normalizer.stubs(:frbr_group_ids).returns([])
    mock_normalizer.expects(:normalize).returns([sample_doc]).at_least_once
    NormalizePrimoResults.expects(:new).returns(mock_normalizer).at_least_once
    SearchController.any_instance.stubs(:fetch_timdex_data).returns(
      { results: [{ api: 'timdex', identifier: 't1', title: 'TIMDEX result' }], hits: 1500 }
    )

    get '/results?q=test&tab=all&page=100'
    assert_response :success

    assert_select '.primo-continuation', count: 1
    assert_select '.primo-continuation h2', text: /limit for Articles, Books & More results/
    assert_select '#results-list .result.use', minimum: 1
    assert_select '.pagination-container .current', text: /1981 - 2000 of 11,500/
    assert_select '.pagination-container .next a[href*="page=101"]'

    get '/results?q=test&tab=all&page=123'
    assert_response :success
    assert_select '#results-list .result.use', minimum: 1
    assert_select '.pagination-container .current', text: /2441 - 2460 of 11,500/
    assert_select '.pagination-container .next a', count: 0
  end

  test 'naturally exhausted Primo results do not show an API limit notice on all tab' do
    mock_primo_search_all_tab
    SearchController.any_instance.stubs(:fetch_timdex_data).returns(
      { results: [{ api: 'timdex', identifier: 't1', title: 'TIMDEX result' }], hits: 1500 }
    )

    get '/results?q=test&tab=all&page=50'

    assert_response :success
    assert_select '#results-list .result.use', minimum: 1
    assert_select '.primo-continuation', count: 0
  end

  test 'all tab pagination displays combined hit counts' do
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
                                          'info' => { 'total' => 500 }
                                        }).at_least_once
    PrimoSearch.expects(:new).returns(mock_primo).at_least_once
    mock_normalizer = mock('normalizer')
    mock_normalizer.stubs(:frbr_group_ids).returns([])
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
                                          'info' => { 'total' => 500 }
                                        }).at_least_once
    PrimoSearch.expects(:new).returns(mock_primo).at_least_once
    mock_normalizer = mock('normalizer')
    mock_normalizer.stubs(:frbr_group_ids).returns([])
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
                                          'info' => { 'total' => 500 }
                                        }).at_least_once
    PrimoSearch.expects(:new).returns(mock_primo).at_least_once
    mock_normalizer = mock('normalizer')
    mock_normalizer.stubs(:frbr_group_ids).returns([])
    mock_normalizer.expects(:normalize).returns(sample_docs).at_least_once
    NormalizePrimoResults.expects(:new).returns(mock_normalizer).at_least_once
    mock_timdex_search_with_hits(300)

    get '/results?q=test&tab=all&page=2'
    assert_response :success

    # Should show previous page link when on page > 1
    assert_select '.pagination-container .previous a[href*="page=1"]'
  end

  test 'all tab does not show pagination controls' do
    ClimateControl.modify(FEATURE_PAGINATION_LOAD_MORE: 'true') do
      mock_primo_search_all_tab
      mock_timdex_search_all_tab

      get '/results?q=test&tab=all'
      assert_response :success
      assert_select '#pagination', count: 0
      assert_select '#load-more'
    end
  end

  test 'all tab shows legacy pagination when load more mode is disabled' do
    ClimateControl.modify(FEATURE_PAGINATION_LOAD_MORE: 'false') do
      mock_primo_search_all_tab
      mock_timdex_search_all_tab

      get '/results?q=test&tab=all'
      assert_response :success
      assert_select '#pagination'
      assert_select '#load-more', count: 0
    end
  end

  test 'append info to payload adds search result context for sml results' do
    controller = SearchController.new
    controller.stubs(:action_name).returns('results')
    controller.instance_variable_set(:@active_tab, 'all')
    controller.instance_variable_set(:@enhanced_query, { q: 'test', queryMode: 'semantic' })
    controller.instance_variable_set(:@primo_result_count, 12)
    controller.instance_variable_set(:@timdex_result_count, 34)
    controller.instance_variable_set(:@frbr_group_ids, %w[group-b group-a])
    payload = {}

    controller.send(:append_info_to_payload, payload)

    assert_equal({
                   search_tab: 'all',
                   primo_result_count: 12,
                   timdex_result_count: 34,
                   searchterm: 'test',
                   query_mode: 'semantic',
                   frbr_group_ids: %w[group-a group-b],
                   ui_mode: 'sml'
                 }, payload.slice(:search_tab, :primo_result_count, :timdex_result_count, :searchterm, :query_mode,
                                  :frbr_group_ids, :ui_mode))
  end

  test 'append info to payload adds geodata ui mode for geodata results' do
    ClimateControl.modify(FEATURE_GEODATA: 'true') do
      controller = SearchController.new
      controller.stubs(:action_name).returns('results')
      controller.instance_variable_set(:@active_tab, nil)
      controller.instance_variable_set(:@enhanced_query, { q: 'parcels', queryMode: 'hybrid' })
      controller.instance_variable_set(:@primo_result_count, 0)
      controller.instance_variable_set(:@timdex_result_count, 56)
      payload = {}

      controller.send(:append_info_to_payload, payload)

      assert_equal({
                     search_tab: 'geodata',
                     primo_result_count: 0,
                     timdex_result_count: 56,
                     searchterm: 'parcels',
                     query_mode: 'hybrid',
                     ui_mode: 'geodata'
                   }, payload.slice(:search_tab, :primo_result_count, :timdex_result_count, :searchterm, :query_mode,
                                    :ui_mode))
      assert_nil payload[:frbr_group_ids]
    end
  end

  test 'append info to payload adds only ui mode outside results action' do
    controller = SearchController.new
    controller.stubs(:action_name).returns('show')
    controller.instance_variable_set(:@enhanced_query, { q: 'test', queryMode: 'semantic' })
    payload = {}

    controller.send(:append_info_to_payload, payload)

    assert_equal 'sml', payload[:ui_mode]
    assert_nil payload[:search_tab]
    assert_nil payload[:primo_result_count]
    assert_nil payload[:timdex_result_count]
    assert_nil payload[:searchterm]
    assert_nil payload[:query_mode]
    assert_nil payload[:frbr_group_ids]
  end

  test 'append info to payload skips result context before enhanced query is built' do
    controller = SearchController.new
    controller.stubs(:action_name).returns('results')
    payload = {}

    controller.send(:append_info_to_payload, payload)

    assert_equal 'sml', payload[:ui_mode]
    assert_nil payload[:search_tab]
    assert_nil payload[:primo_result_count]
    assert_nil payload[:timdex_result_count]
    assert_nil payload[:searchterm]
    assert_nil payload[:query_mode]
    assert_nil payload[:frbr_group_ids]
  end

  test 'collect_frbr_group_ids appends non-blank ids' do
    controller = SearchController.new

    controller.send(:collect_frbr_group_ids, ['group-a'])
    controller.send(:collect_frbr_group_ids, %w[group-b group-c])

    assert_equal %w[group-a group-b group-c], controller.instance_variable_get(:@frbr_group_ids)
  end

  test 'collect_frbr_group_ids ignores blank inputs' do
    controller = SearchController.new

    controller.send(:collect_frbr_group_ids, nil)
    controller.send(:collect_frbr_group_ids, [])

    assert_nil controller.instance_variable_get(:@frbr_group_ids)
  end

  test 'results can include tuning parameters' do
    query = 'fda regulation history medical devices'
    query_mode = 'hybrid'
    tab = 'timdex' # We test the TIMDEX tab because that's the only source that responds to these parameters. Primo will
    # always return the same things.
    default_must = 0.99
    default_drop = 0.0
    alt_must = 0.5
    alt_drop = 0.2

    default_summary = nil
    default_titles = nil
    alt_summary = nil
    alt_titles = nil

    VCR.use_cassette('query tuning stock values') do
      get "/results?q=#{query}&semanticMustBoostThreshold=#{default_must}&semanticDropBoostThreshold=#{default_drop}" \
          "&tab=#{tab}&queryMode=#{query_mode}"
      assert_response :success

      default_summary = css_select('.results-context').first&.text.to_s
      default_titles = css_select('#results .record-title a').map { |result| result.text.squish }
    end

    VCR.use_cassette('query tuning alternate values') do
      get "/results?q=#{query}&semanticMustBoostThreshold=#{alt_must}&semanticDropBoostThreshold=#{alt_drop}" \
          "&tab=#{tab}&queryMode=#{query_mode}"

      assert_response :success

      alt_summary = css_select('.results-context').first&.text.to_s
      alt_titles = css_select('#results .record-title a').map { |result| result.text.squish }
    end

    # Assert these responses were not the same
    assert(default_summary != alt_summary || default_titles != alt_titles,
           'Expected tuning parameters to affect results, but counts and title orders are identical.')
  end

  test 'results can be returned in JSON format when env is set and valid token is provided' do
    secret_value = 'sooper_sekret'
    quepid_ua = 'Quepid/1.0 (Web Scraper)'
    ClimateControl.modify FORMAT_TOKEN: secret_value do
      mock_timdex_search_with_hits(10)
      get "/results?q=test&format=json&format_token=#{secret_value}", headers: { 'HTTP_USER_AGENT' => quepid_ua }
      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
      response_json = JSON.parse(response.body)
      assert_equal %w[results hits errors], response_json.keys
      assert_instance_of Array, response_json['results']
      assert_instance_of Integer, response_json['hits']
    end
  end

  test 'results in JSON format will report zero hit count in the face of missing data' do
    SearchController.any_instance.stubs(:load_timdex_results).returns(nil)
    secret_value = 'sooper_sekret'
    quepid_ua = 'Quepid/1.0 (Web Scraper)'
    # Test @pagination pathway
    ClimateControl.modify FORMAT_TOKEN: secret_value do
      get "/results?q=test&tab=timdex&format=json&format_token=#{secret_value}",
          headers: { 'HTTP_USER_AGENT' => quepid_ua }
      assert_response :success
      response_json = JSON.parse(response.body)
      assert_equal %w[results hits errors], response_json.keys
      assert_equal 0, response_json['hits']
    end
    # Test @load_more pathway
    ClimateControl.modify(FORMAT_TOKEN: secret_value, FEATURE_PAGINATION_LOAD_MORE: 'true') do
      get "/results?q=test&tab=timdex&format=json&format_token=#{secret_value}",
          headers: { 'HTTP_USER_AGENT' => quepid_ua }
      assert_response :success
      response_json = JSON.parse(response.body)
      assert_equal %w[results hits errors], response_json.keys
      assert_equal 0, response_json['hits']
    end
  end

  test 'results can be returned in JSON format when env is set and valid token is provided even with bot challenge' do
    secret_value = 'sooper_sekret'
    quepid_ua = 'Quepid/1.0 (Web Scraper)'

    ClimateControl.modify(FORMAT_TOKEN: secret_value, FEATURE_BOT_DETECTION: 'true') do
      mock_timdex_search_with_hits(10)
      get "/results?q=test&format=json&format_token=#{secret_value}", headers: { 'HTTP_USER_AGENT' => quepid_ua }
      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
      response_json = JSON.parse(response.body)
      assert_equal %w[results hits errors], response_json.keys
      assert_instance_of Array, response_json['results']
      assert_instance_of Integer, response_json['hits']
    end
  end

  test 'results can be returned in JSON format when env is set while load-more pagination is enabled' do
    secret_value = 'sooper_sekret'
    quepid_ua = 'Quepid/1.0 (Web Scraper)'
    ClimateControl.modify(FORMAT_TOKEN: secret_value, FEATURE_PAGINATION_LOAD_MORE: 'true') do
      mock_timdex_search_with_hits(10)
      get "/results?q=test&format=json&format_token=#{secret_value}", headers: { 'HTTP_USER_AGENT' => quepid_ua }
      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
      response_json = JSON.parse(response.body)
      assert_equal %w[results hits errors], response_json.keys
      assert_instance_of Array, response_json['results']
      assert_instance_of Integer, response_json['hits']
    end
  end

  # We don't mock anything here because the error prevents any external lookups
  test 'requests for JSON results without a token generate an unauthorized error' do
    secret_value = 'sooper_sekret'
    ClimateControl.modify FORMAT_TOKEN: secret_value do
      get '/results?q=test&format=json'
      assert_response :unauthorized
    end
  end

  # We don't mock anything here because the error prevents any external lookups
  test 'requests for JSON results when env var is not set generate an unauthorized error' do
    secret_value = 'irrelevant'
    ClimateControl.modify FORMAT_TOKEN: '' do
      get "/results?q=test&format=json&format_token=#{secret_value}"
      assert_response :unauthorized
    end
  end

  # We don't mock anything here because the error prevents any external lookups
  test 'requests for JSON results with an incorrect token generate an unauthorized error' do
    secret_value = 'sooper_sekret'
    wrong_secret = 'something_else'
    refute_equal secret_value, wrong_secret

    ClimateControl.modify FORMAT_TOKEN: secret_value do
      get "/results?q=test&format=json&format_token=#{wrong_secret}"
      assert_response :unauthorized
    end
  end

  test 'requests with unsupported format receive a 406 not-acceptable error' do
    mock_timdex_search_with_hits(10)
    get '/results?q=test&format=xml'
    assert_response :not_acceptable
  end

  test 'requests with invalid format receive a 406 not-acceptable error' do
    mock_timdex_search_with_hits(10)
    get '/results?q=test&format=foo'
    assert_response :not_acceptable
  end

  # Bot detection tests
  test 'bots are redirected to Turnstile challenge' do
    ClimateControl.modify(FEATURE_BOT_DETECTION: 'true') do
      bot_ua = 'Mozilla/5.0 (compatible; Googlebot/2.1)'

      get '/results?q=test', headers: { 'HTTP_USER_AGENT' => bot_ua }

      assert_redirected_to turnstile_path(return_to: '/results?q=test')
    end
  end

  test 'human users bypass Turnstile challenge' do
    ClimateControl.modify(FEATURE_BOT_DETECTION: 'true') do
      human_ua = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/91.0.4472.124 Safari/537.36'
      mock_primo_search_success

      get '/results?q=test&tab=primo', headers: { 'HTTP_USER_AGENT' => human_ua }

      assert_response :success
    end
  end

  test 'bots on non-search paths are not challenged' do
    bot_ua = 'Googlebot/2.1'

    get '/', headers: { 'HTTP_USER_AGENT' => bot_ua }

    # Should not be redirected to Turnstile (doesn't hit SearchController)
    assert_response :success
  end

  # FEATURE_GLOBAL_SCORING tests
  test 'timdex query passes useGlobalScoring: false when FEATURE_GLOBAL_SCORING is disabled' do
    mock_response = build_timdex_mock_response
    TimdexBase::Client.expects(:query).with(
      TimdexSearch::BaseQuery,
      has_entry(:variables, has_entry(:useGlobalScoring, false))
    ).returns(mock_response)

    get '/results?q=data&tab=timdex'
    assert_response :success
  end

  test 'timdex query passes useGlobalScoring: true when FEATURE_GLOBAL_SCORING is enabled' do
    mock_response = build_timdex_mock_response
    ClimateControl.modify(FEATURE_GLOBAL_SCORING: 'true') do
      TimdexBase::Client.expects(:query).with(
        TimdexSearch::BaseQuery,
        has_entry(:variables, has_entry(:useGlobalScoring, true))
      ).returns(mock_response)

      get '/results?q=data&tab=timdex'
      assert_response :success
    end
  end
end
