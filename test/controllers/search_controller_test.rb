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
end
