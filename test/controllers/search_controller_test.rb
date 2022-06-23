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
    assert_select 'select#advanced-source', { count: 1 }
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

      assert_select 'li', 'Keyword anywhere: hallo'
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

  test 'results with valid query has div for facets which is populated' do
    VCR.use_cassette('data basic controller',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=data'
      assert_response :success
      assert_select '#facets'
      assert_select '#facets .category h3', { minimum: 1 }
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

  test 'searches with zero results are handled gracefully' do
    VCR.use_cassette('timdex no results',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=asdfiouwenlasd'
      assert_response :success
      # Result list contents state "no results"
      assert_select '#results'
      assert_select '#results', { count: 1 }
      assert_select '#results li', 'There are no results.'
      # Facets are not shown
      assert_select '#facets'
      assert_select '#facets .category h3', { count: 0 }
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

      assert_select 'li', 'Citation: asdf'
    end
  end

  test 'advanced search can accept values from all fields' do
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
end
