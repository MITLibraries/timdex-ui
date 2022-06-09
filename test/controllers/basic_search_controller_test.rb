require 'test_helper'

class BasicSearchControllerTest < ActionDispatch::IntegrationTest
  test 'index shows search form' do
    get '/'
    assert_response :success

    assert_select 'form#basic-search', { count: 1 }
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
      # Facets are present, but empty
      assert_select '#facets'
      assert_select '#facets .category h3', { minimum: 1 }
      assert_select '#facets .category ul.category-terms li.term', { count: 0 }
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
end
