require 'test_helper'

class RackAttackCookieBypassTest < ActionDispatch::IntegrationTest
  # Test that grace period cookies actually bypass throttling.
  # Makes rapid requests to naturally trigger Rack::Attack throttle counters,
  # then tests if valid/invalid cookies bypass throttles accordingly.

  def setup
    # Clear cache before each test
    Rails.cache.clear

    # Stub PrimoSearch to avoid external API calls
    stub_primo_search

    # Stub TimdexBase::Client to avoid external GraphQL calls
    stub_timdex_client
  end

  def stub_primo_search
    PrimoSearch.any_instance.stubs(:search).returns(
      {
        'info' => {
          'total' => 100,
          'first' => 1,
          'last' => 10
        },
        'docs' => [
          {
            'pnx' => {
              'addata' => {
                'title' => ['Test Result']
              }
            }
          }
        ]
      }
    )
  end

  def stub_timdex_client
    mock_response = Object.new
    mock_response.stubs(:data).returns(Object.new)
    mock_response.stubs(:errors).returns(Object.new)

    # Mock data.to_h
    mock_response.data.stubs(:to_h).returns(
      {
        'recordId' => {
          'title' => 'Test Record',
          'timdexRecordId' => 'test-id'
        }
      }
    )

    # Mock errors.details.to_h
    mock_response.errors.stubs(:details).returns(Object.new)
    mock_response.errors.details.stubs(:to_h).returns({})

    TimdexBase::Client.stubs(:query).returns(mock_response)
  end

  def trigger_throttle_via_requests(endpoint_path, count, cookie_value = nil, params:)
    # Make rapid requests to trigger Rack::Attack counter
    # Each request increments the cache counter for this IP/throttle
    count.times do
      headers = {}
      headers['HTTP_COOKIE'] = "turnstile_verified_at=#{cookie_value}" if cookie_value
      get endpoint_path, params: params, headers: headers
    end
  end

  def turnstile_cookie(expiration_time)
    Rails.application.message_verifier(:turnstile_grace).generate(expiration_time.to_i)
  end

  def rack_request_with_turnstile_cookie(cookie_value = nil)
    cookie_header = cookie_value ? "turnstile_verified_at=#{cookie_value}" : nil
    Rack::Request.new('HTTP_COOKIE' => cookie_header)
  end

  test 'turnstile_grace_cookie_valid? validates signed future expiration cookie' do
    refute Rack::Attack.turnstile_grace_cookie_valid?(rack_request_with_turnstile_cookie)
    refute Rack::Attack.turnstile_grace_cookie_valid?(rack_request_with_turnstile_cookie('tampered-value'))
    refute Rack::Attack.turnstile_grace_cookie_valid?(rack_request_with_turnstile_cookie(turnstile_cookie(Time.current - 1.minute)))

    assert Rack::Attack.turnstile_grace_cookie_valid?(rack_request_with_turnstile_cookie(turnstile_cookie(Time.current + 15.minutes)))
  end

  test 'req_ip_free_path? identifies cheap paths excluded from general request throttle' do
    assert Rack::Attack.req_ip_free_path?('/')
    assert Rack::Attack.req_ip_free_path?('/assets/application.css')
    assert Rack::Attack.req_ip_free_path?('/turnstile/verify')
    assert Rack::Attack.req_ip_free_path?('/about')
    assert Rack::Attack.req_ip_free_path?('/about-natural-language-search')

    refute Rack::Attack.req_ip_free_path?('/results')
    refute Rack::Attack.req_ip_free_path?('/record/test-id')
    refute Rack::Attack.req_ip_free_path?('/style-guide')
    refute Rack::Attack.req_ip_free_path?('/aboutness')
  end

  test 'valid grace period cookie bypasses throttle when throttle is active' do
    # Get the throttle limit from environment or use default
    limit = ENV.fetch('RESULTS_GLOBAL_LIMIT_PER_SEC', 30).to_i

    # Create a valid, non-expired cookie
    future_timestamp = (Time.current + 15.minutes).to_i
    valid_cookie = turnstile_cookie(future_timestamp)

    # Make requests WITHOUT cookie to build up throttle counter
    trigger_throttle_via_requests('/results', limit + 5, params: { q: 'test', tab: 'primo' })

    # Now make a request WITH valid cookie - should bypass throttle
    get '/results', params: { q: 'test', tab: 'primo' },
                    headers: { 'HTTP_COOKIE' => "turnstile_verified_at=#{valid_cookie}" }

    # Should NOT be throttled - valid cookie bypasses the throttle
    assert_response :success, 'Valid grace period cookie should bypass throttle'
  end

  test 'invalid cookie does not bypass throttle when throttle is active' do
    # Get the throttle limit
    limit = ENV.fetch('RESULTS_GLOBAL_LIMIT_PER_SEC', 30).to_i

    # Create an invalid/tampered cookie
    invalid_cookie = 'tampered-value-that-will-not-verify'

    # Build up throttle counter without any cookie
    trigger_throttle_via_requests('/results', limit + 5, params: { q: 'test', tab: 'primo' })

    # Now make a request WITH invalid cookie - should still be throttled
    get '/results', params: { q: 'test', tab: 'primo' },
                    headers: { 'HTTP_COOKIE' => "turnstile_verified_at=#{invalid_cookie}" }

    # Should be throttled and redirected to Turnstile (not bypassed)
    assert_equal 302, status, 'Invalid cookie should not bypass throttle'
    assert response.location.include?('/turnstile'), 'Should redirect to Turnstile on throttle'
  end

  test 'expired cookie does not bypass throttle when throttle is active' do
    limit = ENV.fetch('RESULTS_GLOBAL_LIMIT_PER_SEC', 30).to_i

    # Create a validly-signed but expired cookie
    past_timestamp = (Time.current - 1.minute).to_i
    expired_cookie = turnstile_cookie(past_timestamp)

    # Build up throttle counter
    trigger_throttle_via_requests('/results', limit + 5, params: { q: 'test', tab: 'primo' })

    # Request with expired cookie should be throttled
    get '/results', params: { q: 'test', tab: 'primo' },
                    headers: { 'HTTP_COOKIE' => "turnstile_verified_at=#{expired_cookie}" }

    # Should be throttled and redirected
    assert_equal 302, status, 'Expired cookie should not bypass throttle'
    assert response.location.include?('/turnstile'), 'Should redirect to Turnstile on throttle'
  end

  test 'missing cookie does not bypass throttle when throttle is active' do
    limit = ENV.fetch('RESULTS_GLOBAL_LIMIT_PER_SEC', 30).to_i

    # Build up throttle counter
    trigger_throttle_via_requests('/results', limit + 5, params: { q: 'test', tab: 'primo' })

    # Request without any turnstile_verified_at cookie
    get '/results', params: { q: 'test', tab: 'primo' }

    # Should be throttled and redirected
    assert_equal 302, status, 'Missing cookie should not bypass throttle'
    assert response.location.include?('/turnstile'), 'Should redirect to Turnstile on throttle'
  end

  test 'malformed cookie does not bypass throttle when throttle is active' do
    limit = ENV.fetch('RESULTS_GLOBAL_LIMIT_PER_SEC', 30).to_i

    # Create a malformed cookie
    malformed_cookie = ';;;invalid;;;not-base64;;;'

    # Build up throttle counter
    trigger_throttle_via_requests('/results', limit + 5, params: { q: 'test', tab: 'primo' })

    # Request with malformed cookie
    get '/results', params: { q: 'test', tab: 'primo' },
                    headers: { 'HTTP_COOKIE' => "turnstile_verified_at=#{malformed_cookie}" }

    # Should be throttled and redirected
    assert_equal 302, status, 'Malformed cookie should not bypass throttle'
    assert response.location.include?('/turnstile'), 'Should redirect to Turnstile on throttle'
  end

  test 'valid cookie bypasses req/ip/results throttle on /record endpoint' do
    # Test that valid cookies work for /record endpoint (which has req/ip/results throttle)
    # Use the same env vars as the actual throttle configuration
    limit = ENV.fetch('RESULTS_THROTTLE_LIMIT', 10).to_i

    future_timestamp = (Time.current + 15.minutes).to_i
    valid_cookie = turnstile_cookie(future_timestamp)

    # Build up throttle counter for /record endpoint
    trigger_throttle_via_requests('/record/test-id', limit + 5, params: {})

    # Now make request with valid cookie - should bypass throttle
    get '/record/test-id', headers: { 'HTTP_COOKIE' => "turnstile_verified_at=#{valid_cookie}" }

    # Should NOT be throttled
    assert_response :success, 'Valid grace period cookie should bypass throttle on /record'
  end

  test 'valid cookie bypasses general req/ip throttle' do
    limit = ENV.fetch('REQUESTS_PER_PERIOD', 100).to_i
    valid_cookie = turnstile_cookie(Time.current + 15.minutes)

    trigger_throttle_via_requests('/style-guide', limit + 5, params: {})

    get '/style-guide', headers: { 'HTTP_COOKIE' => "turnstile_verified_at=#{valid_cookie}" }

    assert_response :success, 'Valid grace period cookie should bypass the general req/ip throttle'
  end

  test 'invalid cookie does not bypass general req/ip throttle and redirects to Turnstile' do
    limit = ENV.fetch('REQUESTS_PER_PERIOD', 100).to_i

    trigger_throttle_via_requests('/style-guide', limit + 5, params: {})

    get '/style-guide', headers: { 'HTTP_COOKIE' => 'turnstile_verified_at=tampered-value' }

    assert_equal 302, status, 'Invalid cookie should not bypass the general req/ip throttle'
    assert response.location.include?('/turnstile'), 'Should redirect to Turnstile on throttle'
  end

  test 'free paths do not count against general req/ip throttle' do
    limit = ENV.fetch('REQUESTS_PER_PERIOD', 100).to_i

    [ '/', '/about', '/about-natural-language-search' ].each do |path|
      trigger_throttle_via_requests(path, limit + 5, params: {})
    end

    get '/style-guide'

    assert_response :success, 'Cheap/free paths should not increment the general req/ip throttle counter'
  end
end
