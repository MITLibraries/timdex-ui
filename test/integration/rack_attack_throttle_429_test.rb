require 'test_helper'

class RackAttackThrottle429Test < ActionDispatch::IntegrationTest
  # Test that throttles without grace period support (req/ip, req/ip/redirects)
  # return a 429 response instead of redirecting to Turnstile.
  #
  # Note: These tests use mocking to simulate Rack::Attack throttle conditions
  # because env vars are read at class load time, not request time. We test the
  # response logic by directly calling the throttled_responder lambda.

  def build_mock_env(path: '/results', query_string: '', matched_throttle: 'req/ip')
    {
      'REQUEST_METHOD' => 'GET',
      'PATH_INFO' => path,
      'QUERY_STRING' => query_string,
      'SERVER_NAME' => 'localhost',
      'SERVER_PORT' => '80',
      'rack.url_scheme' => 'http',
      'rack.attack.matched' => matched_throttle,
      'HTTP_USER_AGENT' => 'Mozilla/5.0'
    }
  end

  test 'req/ip throttle returns 429 (not Turnstile redirect)' do
    # The req/ip throttle has no grace period, so it should return 429
    env = build_mock_env(path: '/about', matched_throttle: 'req/ip')

    status, headers, body = Rack::Attack.throttled_responder.call(env)

    assert_equal 429, status
    assert_equal 'text/plain', headers['Content-Type']
    assert_equal ['Too Many Requests'], body
  end

  test 'req/ip/redirects throttle returns 429 (not Turnstile redirect)' do
    # The req/ip/redirects throttle has no grace period, so it should return 429
    env = build_mock_env(path: '/', query_string: 'geoweb-redirect=primo', matched_throttle: 'req/ip/redirects')

    status, headers, body = Rack::Attack.throttled_responder.call(env)

    assert_equal 429, status
    assert_equal 'text/plain', headers['Content-Type']
    assert_equal ['Too Many Requests'], body
  end

  test 'results/global throttle redirects to Turnstile (not 429)' do
    # The results/global throttle has grace period support, so it should redirect
    env = build_mock_env(path: '/results', query_string: 'q=test', matched_throttle: 'results/global')

    status, headers, _body = Rack::Attack.throttled_responder.call(env)

    # Should redirect to Turnstile, not return 429
    assert_equal 302, status
    assert headers['Location'].include?('/turnstile')
    assert headers['Location'].include?('return_to=')
  end

  test 'req/ip/results throttle redirects to Turnstile (not 429)' do
    # The req/ip/results throttle has grace period support, so it should redirect
    env = build_mock_env(path: '/record/123', matched_throttle: 'req/ip/results')

    status, headers, _body = Rack::Attack.throttled_responder.call(env)

    # Should redirect to Turnstile, not return 429
    assert_equal 302, status
    assert headers['Location'].include?('/turnstile')
  end

  test 'throttled_responder logs all throttled requests' do
    # Verify that logging happens for all throttled requests
    env = build_mock_env(path: '/about', matched_throttle: 'req/ip')

    # Expect a warn-level log
    Rails.logger.expects(:warn).with do |msg|
      msg.include?('THROTTLED_REQUEST') &&
        msg.include?('UA=') &&
        msg.include?('IP=') &&
        msg.include?('Path=') &&
        msg.include?('Throttle=')
    end.at_least_once

    Rack::Attack.throttled_responder.call(env)
  end

  test '429 response includes plain text content type and body' do
    # Verify the exact response format for 429 errors
    env = build_mock_env(path: '/api/endpoint', matched_throttle: 'req/ip')

    status, headers, body = Rack::Attack.throttled_responder.call(env)

    assert_equal 429, status
    assert_equal 'text/plain', headers['Content-Type']
    assert_equal 'Too Many Requests', body.first
  end
end
