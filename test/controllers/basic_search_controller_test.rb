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
    get '/results?q=hallo'
    assert_response :success
    assert_nil flash[:error]

    assert_select '.search-summary', 'Showing results for "hallo"'
  end

  test 'results with valid query shows search form' do
    get '/results?q=hallo'
    assert_response :success

    assert_select '#basic-search label', 'Search the MIT Libraries'
  end

  test 'results with valid query populates search form with query' do
    get '/results?q=hallo'
    assert_response :success

    assert_select '#basic-search-main[value=hallo]'
  end

  test 'results with valid query has div for hints' do
    get '/results?q=hallo'
    assert_response :success

    assert_select '#hint'
  end

  test 'results with valid query has div for facets' do
    get '/results?q=hallo'
    assert_response :success

    assert_select '#facets'
  end

  test 'results with valid query has div for pagination' do
    get '/results?q=hallo'
    assert_response :success

    assert_select '#pagination'
  end

  test 'results with valid query has div for results' do
    get '/results?q=hallo'
    assert_response :success

    assert_select '#results'
  end
end
