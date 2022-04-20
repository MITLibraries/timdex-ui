require 'test_helper'

class BasicSearchControllerTest < ActionDispatch::IntegrationTest
  test 'index shows search form' do
    get '/'
    assert_response :success

    assert_select '#basic-search label', 'Search the MIT Libraries'
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
                     allow_playback_repeats: true) do
      get '/results?q=hallo'
      assert_response :success
      assert_nil flash[:error]

      assert_select '.search-summary', 'Showing results for "hallo"'
    end
  end

  test 'results with valid query shows search form' do
    VCR.use_cassette('timdex hallo',
                     allow_playback_repeats: true) do
      get '/results?q=hallo'
      assert_response :success

      assert_select '#basic-search label', 'Search the MIT Libraries'
    end
  end

  test 'results with valid query populates search form with query' do
    VCR.use_cassette('timdex hallo',
                     allow_playback_repeats: true) do
      get '/results?q=hallo'
      assert_response :success

      assert_select '#basic-search-main[value=hallo]'
    end
  end

  test 'results with valid query has div for hints' do
    VCR.use_cassette('timdex hallo',
                     allow_playback_repeats: true) do
      get '/results?q=hallo'
      assert_response :success

      assert_select '#hint'
    end
  end

  test 'results with valid query has div for facets which is populated' do
    VCR.use_cassette('timdex hallo',
                     allow_playback_repeats: true) do
      get '/results?q=hallo'
      assert_response :success
      assert_select '#facets'
      assert_select '#facets .category h4', { minimum: 1 }
    end
  end

  test 'results with valid query has div for pagination' do
    VCR.use_cassette('timdex hallo',
                     allow_playback_repeats: true) do
      get '/results?q=hallo'
      assert_response :success

      assert_select '#pagination'
    end
  end

  test 'results with valid query has div for results which is populated' do
    VCR.use_cassette('timdex hallo',
                     allow_playback_repeats: true) do
      get '/results?q=hallo'
      assert_response :success
      assert_select '#results'
      assert_select '#results ul li', { minimum: 1 }
    end
  end

  test 'searches with zero results are handled gracefully' do
    VCR.use_cassette('timdex no results',
                     allow_playback_repeats: true) do
      get '/results?q=asdfiouwenlasd'
      assert_response :success
      # Result list contents state "no results"
      assert_select '#results'
      assert_select '#results ul li', { count: 1 }
      assert_select '#results ul li', 'There are no results.'
      # Facets are present, but empty
      assert_select '#facets'
      assert_select '#facets .category h4', { minimum: 1 }
      assert_select '#facets .category ul.category-terms li.term', { count: 0 }
    end
  end

  test 'searches with ISSN display issn fact card' do
    VCR.use_cassette('timdex 1234-5678',
                     allow_playback_repeats: true) do
      get '/results?q=1234-5678'
      assert_response :success

      assert_select '#issn-fact', { count: 1 }
      assert_select '#isbn-fact', { count: 0 }
    end
  end

  test 'searches with ISBN display isbn fact card' do
    VCR.use_cassette('timdex 9781509053278',
                     allow_playback_repeats: true) do
      get '/results?q=9781509053278'
      assert_response :success

      assert_select '#issn-fact', { count: 0 }
      assert_select '#isbn-fact', { count: 1 }
    end
  end
end
