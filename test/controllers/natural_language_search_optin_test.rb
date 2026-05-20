require 'test_helper'
require 'cgi'

class NaturalLanguageSearchOptinTest < ActionDispatch::IntegrationTest
  def mock_timdex_success
    mock_response = mock('timdex_response')
    mock_errors = mock('timdex_errors')
    mock_errors.stubs(:details).returns({})
    mock_errors.stubs(:to_h).returns({})
    mock_response.stubs(:errors).returns(mock_errors)

    mock_data = mock('timdex_data')
    mock_search = mock('timdex_search')
    sample_result = {
      'title' => 'Sample Result',
      'timdexRecordId' => 'test-123',
      'contentType' => ['Article']
    }
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

    TimdexBase::Client.stubs(:query).returns(mock_response)
  end

  def mock_primo_success
    sample_doc = {
      api: 'primo',
      title: 'Sample Primo Result',
      format: 'Article'
    }

    mock_primo = mock('primo_search')
    mock_primo.stubs(:search).returns({ 'docs' => [sample_doc], 'info' => { 'total' => 1 } })
    PrimoSearch.stubs(:new).returns(mock_primo)

    mock_normalizer = mock('normalizer')
    mock_normalizer.stubs(:normalize).returns([sample_doc])
    NormalizePrimoResults.stubs(:new).returns(mock_normalizer)
  end

  test 'route with natural_language_search_optin=true sets cookie' do
    get '/natural_language_search_optin?natural_language_search_optin=true'
    assert_response :redirect
    assert_equal cookies['natural_language_search_optin'], 'true'
  end

  test 'route with natural_language_search_optin=false sets cookie to false' do
    get '/natural_language_search_optin?natural_language_search_optin=false'
    assert_response :redirect
    assert_equal cookies['natural_language_search_optin'], 'false'
  end

  test 'route with no parameter deletes cookie' do
    get '/natural_language_search_optin?natural_language_search_optin=true'
    assert_equal cookies['natural_language_search_optin'], 'true'

    get '/natural_language_search_optin'
    assert_response :redirect

    # Rails sets cookies to empty string when deleted via cookies.delete
    assert(cookies['natural_language_search_optin'].blank?)
  end

  test 'route redirects to return_to when provided' do
    get '/natural_language_search_optin?natural_language_search_optin=true&return_to=/results?q=test'
    assert_response :redirect
    assert_redirected_to '/results?q=test'
  end

  test 'route redirects to root when no referer or return_to' do
    get '/natural_language_search_optin?natural_language_search_optin=true'
    assert_response :redirect
    assert_redirected_to root_path
  end

  test 'toggle shows toggled-off by default (no cookie)' do
    mock_timdex_success
    get '/results?q=test&tab=timdex'

    assert_response :success
    assert_select 'div.semantic-search-toggle.toggled-off'
  end

  test 'toggle shows toggled-on when opted-in' do
    get '/natural_language_search_optin?natural_language_search_optin=true'

    mock_timdex_success
    get '/results?q=test&tab=timdex'

    assert_response :success
    assert_select 'div.semantic-search-toggle.toggled-on'
  end

  test 'toggle shows toggled-off when opted-out' do
    get '/natural_language_search_optin?natural_language_search_optin=false'

    mock_timdex_success
    get '/results?q=test&tab=timdex'

    assert_response :success
    assert_select 'div.semantic-search-toggle.toggled-off'
  end

  test 'route with return_to redirects to that path' do
    mock_timdex_success
    get '/results?q=test&tab=timdex'

    assert_response :success

    return_to = '/results?q=test&tab=timdex&page=2'
    get "/natural_language_search_optin?natural_language_search_optin=true&return_to=#{CGI.escape(return_to)}"

    assert_response :redirect
    assert_redirected_to return_to
  end

  test '@natural_language_search_optin is true when cookie is true' do
    get '/natural_language_search_optin?natural_language_search_optin=true'

    mock_timdex_success
    get '/results?q=test&tab=timdex'

    assert_response :success
    assert_equal controller.view_context.assigns['natural_language_search_optin'], true
  end

  test '@natural_language_search_optin is false when cookie is false' do
    get '/natural_language_search_optin?natural_language_search_optin=false'

    mock_timdex_success
    get '/results?q=test&tab=timdex'

    assert_response :success
    assert_equal controller.view_context.assigns['natural_language_search_optin'], false
  end

  test '@natural_language_search_optin is false when no cookie' do
    mock_timdex_success
    get '/results?q=test&tab=timdex'

    assert_response :success
    assert_equal controller.view_context.assigns['natural_language_search_optin'], false
  end

  test 'URL param queryMode overrides cookie' do
    get '/natural_language_search_optin?natural_language_search_optin=true'
    assert_equal cookies['natural_language_search_optin'], 'true'

    mock_timdex_success
    get '/results?q=test&tab=timdex&queryMode=keyword'

    assert_response :success
    assert_equal cookies['natural_language_search_optin'], 'true'
  end

  test 'cookie unchanged after search with URL param override' do
    get '/natural_language_search_optin?natural_language_search_optin=false'
    assert_equal cookies['natural_language_search_optin'], 'false'

    mock_timdex_success
    get '/results?q=test&tab=timdex&queryMode=hybrid'

    assert_response :success
    assert_equal cookies['natural_language_search_optin'], 'false'
  end

  test 'cookie=true, no param: user is opted-in' do
    get '/natural_language_search_optin?natural_language_search_optin=true'
    mock_timdex_success

    get '/results?q=test&tab=timdex'
    assert_response :success
    assert_equal controller.view_context.assigns['natural_language_search_optin'], true
  end

  test 'cookie=false, no param: user is opted-out' do
    get '/natural_language_search_optin?natural_language_search_optin=false'
    mock_timdex_success

    get '/results?q=test&tab=timdex'
    assert_response :success
    assert_equal controller.view_context.assigns['natural_language_search_optin'], false
  end

  test 'no cookie, no param: user is not opted-in' do
    mock_timdex_success
    get '/results?q=test&tab=timdex'

    assert_response :success
    assert_equal controller.view_context.assigns['natural_language_search_optin'], false
  end

  test 'cookie-driven queryMode works on timdex tab' do
    get '/natural_language_search_optin?natural_language_search_optin=true'
    mock_timdex_success

    get '/results?q=test&tab=timdex'
    assert_response :success
  end

  test 'cookie-driven queryMode works on all tab' do
    get '/natural_language_search_optin?natural_language_search_optin=true'

    mock_timdex_success
    mock_primo_success

    get '/results?q=test&tab=all'
    assert_response :success
  end

  test 'warning shows on Primo tab when opted-in' do
    get '/natural_language_search_optin?natural_language_search_optin=true'

    mock_primo_success
    get '/results?q=test&tab=cdi'

    assert_response :success
    assert_select 'aside.nls-alert', count: 1
  end

  test 'warning does not show on TIMDEX tab when opted-in' do
    get '/natural_language_search_optin?natural_language_search_optin=true'

    mock_timdex_success
    get '/results?q=test&tab=timdex'

    assert_response :success
    assert_select 'aside.nls-alert', count: 0
  end

  test 'warning does not show on articles tab when opted-out' do
    get '/natural_language_search_optin?natural_language_search_optin=false'

    mock_primo_success
    get '/results?q=test&tab=cdi'

    assert_response :success
    assert_select 'aside.nls-alert', count: 0
  end

  test 'warning does not show on articles tab with no opt-in cookie' do
    mock_primo_success
    get '/results?q=test&tab=cdi'

    assert_response :success
    assert_select 'aside.nls-alert', count: 0
  end

  test 'warning shows on alma tab when opted-in' do
    get '/natural_language_search_optin?natural_language_search_optin=true'

    mock_primo_success
    get '/results?q=test&tab=alma'

    assert_response :success
    assert_select 'aside.nls-alert', count: 1
  end

  test 'warning shows on cdi tab when opted-in' do
    get '/natural_language_search_optin?natural_language_search_optin=true'

    mock_primo_success
    get '/results?q=test&tab=cdi'

    assert_response :success
    assert_select 'aside.nls-alert', count: 1
  end

  test '@show_nls_warning is true when opted-in on Primo tab' do
    get '/natural_language_search_optin?natural_language_search_optin=true'

    mock_primo_success
    get '/results?q=test&tab=cdi'

    assert_response :success
    assert_equal controller.view_context.assigns['show_nls_warning'], true
  end

  test '@show_nls_warning is false when opted-in on TIMDEX tab' do
    get '/natural_language_search_optin?natural_language_search_optin=true'

    mock_timdex_success
    get '/results?q=test&tab=timdex'

    assert_response :success
    assert_equal controller.view_context.assigns['show_nls_warning'], false
  end

  test '@show_nls_warning is false when opted-out on Primo tab' do
    get '/natural_language_search_optin?natural_language_search_optin=false'

    mock_primo_success
    get '/results?q=test&tab=cdi'

    assert_response :success
    assert_equal controller.view_context.assigns['show_nls_warning'], false
  end
end
