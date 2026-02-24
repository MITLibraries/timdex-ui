require 'test_helper'

class TurnstileControllerTest < ActionDispatch::IntegrationTest
  test 'GET /turnstile renders challenge page' do
    ClimateControl.modify(TURNSTILE_SITEKEY: 'test-sitekey', TURNSTILE_SECRET: 'test-secret') do
      get turnstile_path

      assert_response :success
      assert_select '.cf-turnstile'
      assert_select 'h1', text: "Prove you're not a bot"
    end
  end

  test 'GET /turnstile passes sitekey to view' do
    ClimateControl.modify(TURNSTILE_SITEKEY: 'another-test-sitekey') do
      get turnstile_path

      assert_response :success
      assert_select 'div.cf-turnstile[data-sitekey="another-test-sitekey"]'
    end
  end

  test 'GET /turnstile uses empty sitekey if env var missing' do
    ClimateControl.modify(TURNSTILE_SITEKEY: nil) do
      get turnstile_path

      assert_response :success
      assert_select '.cf-turnstile'
    end
  end

  test 'GET /turnstile preserves return_to parameter' do
    ClimateControl.modify(TURNSTILE_SITEKEY: 'test-sitekey') do
      return_to = '/results?q=test'
      get turnstile_path(return_to: return_to)

      assert_response :success
      assert_select "input[name='return_to'][value='#{return_to}']"
    end
  end

  test 'GET /turnstile defaults return_to to root_path' do
    ClimateControl.modify(TURNSTILE_SITEKEY: 'test-sitekey') do
      get turnstile_path

      assert_response :success
      assert_select "input[name='return_to'][value='/']"
    end
  end

  test 'POST /turnstile/verify with missing token redirects with error' do
    post turnstile_verify_path, params: { return_to: '/results' }

    assert_redirected_to turnstile_path(return_to: '/results')
    assert_equal 'Turnstile validation failed. Please try again.', flash[:error]
  end

  test 'POST /turnstile/verify with valid token sets session and redirects' do
    # Stub the HTTP post to Cloudflare to return success
    stub_response = { 'success' => true, 'challenge_ts' => '2024-02-24T10:00:00Z' }
    response_mock = mock(to_s: stub_response.to_json)
    HTTP.stubs(:post).returns(response_mock)

    post turnstile_verify_path, params: {
      'cf-turnstile-response' => 'success_token',
      return_to: '/results?q=test'
    }

    assert_redirected_to '/results?q=test'
    assert session[:passed_turnstile]
  end

  test 'POST /turnstile/verify with invalid token redirects with error' do
    # Stub the HTTP post to Cloudflare to return failure
    stub_response = { 'success' => false, 'error-codes' => ['invalid-input-response'] }
    response_mock = mock(to_s: stub_response.to_json)
    HTTP.stubs(:post).returns(response_mock)

    post turnstile_verify_path, params: {
      'cf-turnstile-response' => 'invalid_token',
      return_to: '/results'
    }

    assert_redirected_to turnstile_path(return_to: '/results')
    assert_equal 'Turnstile verification failed. Please try again.', flash[:error]
    assert_nil session[:passed_turnstile]
  end

  test 'POST /turnstile/verify with missing secret returns error' do
    ClimateControl.modify(TURNSTILE_SECRET: nil) do
      post turnstile_verify_path, params: {
        'cf-turnstile-response' => 'token',
        return_to: '/results'
      }

      assert_redirected_to turnstile_path(return_to: '/results')
      assert_equal 'Turnstile verification failed. Please try again.', flash[:error]
    end
  end

  test 'POST /turnstile/verify defaults return_to to root_path' do
    stub_response = { 'success' => true, 'challenge_ts' => '2024-02-24T10:00:00Z' }
    response_mock = mock(to_s: stub_response.to_json)
    HTTP.stubs(:post).returns(response_mock)

    post turnstile_verify_path, params: {
      'cf-turnstile-response' => 'success_token'
    }

    assert_redirected_to root_path
    assert session[:passed_turnstile]
  end

  test 'POST /turnstile/verify handles verification API errors gracefully' do
    # Mock the HTTP call to raise an error
    HTTP.stubs(:post).raises(StandardError.new('Connection timeout'))

    post turnstile_verify_path, params: {
      'cf-turnstile-response' => 'token',
      return_to: '/results'
    }

    assert_redirected_to turnstile_path(return_to: '/results')
    assert_equal 'Turnstile verification failed. Please try again.', flash[:error]
  end

end
