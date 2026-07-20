require 'test_helper'

class RackAttackFormatTokenBypassTest < ActionDispatch::IntegrationTest
  # Test that requests with valid format tokens bypass Rack::Attack throttling.
  # Similar to the Turnstile grace cookie bypass tests, but for programmatic API requests.

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

  def rack_request_with_format_token(token_value = nil)
    params = token_value ? "format_token=#{token_value}" : ''
    Rack::Request.new('QUERY_STRING' => params)
  end

  test 'valid_format_token? returns false when FORMAT_TOKEN env var is blank' do
    ClimateControl.modify(FORMAT_TOKEN: '') do
      refute Rack::Attack.valid_format_token?(rack_request_with_format_token('some-token'))
    end
  end

  test 'valid_format_token? returns false when format_token param is missing' do
    ClimateControl.modify(FORMAT_TOKEN: 'valid-token') do
      refute Rack::Attack.valid_format_token?(rack_request_with_format_token)
      refute Rack::Attack.valid_format_token?(rack_request_with_format_token(''))
    end
  end

  test 'valid_format_token? returns false when token does not match' do
    ClimateControl.modify(FORMAT_TOKEN: 'valid-token') do
      refute Rack::Attack.valid_format_token?(rack_request_with_format_token('wrong-token'))
      refute Rack::Attack.valid_format_token?(rack_request_with_format_token('tampered-token'))
    end
  end

  test 'valid_format_token? returns true when token matches FORMAT_TOKEN env var' do
    ClimateControl.modify(FORMAT_TOKEN: 'valid-token') do
      assert Rack::Attack.valid_format_token?(rack_request_with_format_token('valid-token'))
    end
  end

  test 'valid_format_token? uses secure comparison to prevent timing attacks' do
    ClimateControl.modify(FORMAT_TOKEN: 'valid-token') do
      req = rack_request_with_format_token('valid-token')

      ActiveSupport::SecurityUtils.expects(:secure_compare).with('valid-token', 'valid-token').returns(true)

      assert Rack::Attack.valid_format_token?(req)
    end
  end

  test 'valid_format_token? handles malformed requests gracefully' do
    ClimateControl.modify(FORMAT_TOKEN: 'valid-token') do
      # Test with request that has no query string
      env = Rack::Request.new({})
      refute Rack::Attack.valid_format_token?(env)
    end
  end

  test 'valid format token bypasses results/global throttle on /results endpoint' do
    ClimateControl.modify(FORMAT_TOKEN: 'valid-api-token') do
      # Get the throttle limit from environment or use default
      limit = ENV.fetch('RESULTS_GLOBAL_LIMIT_PER_SEC', 30).to_i

      # Make requests WITHOUT token to build up throttle counter
      (limit + 5).times do
        get '/results', params: { q: 'test', tab: 'primo' }
      end

      # Now make a request WITH valid token - should bypass throttle
      get '/results', params: { q: 'test', tab: 'primo', format_token: 'valid-api-token' }

      # Should NOT be throttled - valid token bypasses the throttle
      assert_response :success, 'Valid format token should bypass results/global throttle'
    end
  end

  test 'invalid format token does not bypass results/global throttle' do
    ClimateControl.modify(FORMAT_TOKEN: 'valid-api-token') do
      limit = ENV.fetch('RESULTS_GLOBAL_LIMIT_PER_SEC', 30).to_i

      # Build up throttle counter
      (limit + 5).times do
        get '/results', params: { q: 'test', tab: 'primo' }
      end

      # Make request with invalid token - should still be throttled
      get '/results', params: { q: 'test', tab: 'primo', format_token: 'wrong-token' }

      # Should be throttled and redirected to Turnstile
      assert_equal 302, status, 'Invalid format token should not bypass throttle'
      assert response.location.include?('/turnstile'), 'Should redirect to Turnstile on throttle'
    end
  end

  test 'missing format token does not bypass results/global throttle' do
    ClimateControl.modify(FORMAT_TOKEN: 'valid-api-token') do
      limit = ENV.fetch('RESULTS_GLOBAL_LIMIT_PER_SEC', 30).to_i

      # Build up throttle counter
      (limit + 5).times do
        get '/results', params: { q: 'test', tab: 'primo' }
      end

      # Make request without token parameter
      get '/results', params: { q: 'test', tab: 'primo' }

      # Should be throttled and redirected
      assert_equal 302, status, 'Missing format token should not bypass throttle'
      assert response.location.include?('/turnstile'), 'Should redirect to Turnstile on throttle'
    end
  end

  test 'valid format token bypasses req/ip/results throttle on /record endpoint' do
    stub_timdex_client
    ClimateControl.modify(FORMAT_TOKEN: 'valid-api-token') do
      # Use the same env vars as the actual throttle configuration
      limit = ENV.fetch('RESULTS_THROTTLE_LIMIT', 10).to_i

      # Build up throttle counter for /record endpoint
      (limit + 5).times do
        get '/record/test-id'
      end

      # Now make request with valid token - should bypass throttle
      get '/record/test-id', params: { format_token: 'valid-api-token' }

      # Should NOT be throttled
      assert_response :success, 'Valid format token should bypass req/ip/results throttle on /record'
    end
  end

  test 'invalid format token does not bypass req/ip/results throttle on /record' do
    stub_timdex_client
    ClimateControl.modify(FORMAT_TOKEN: 'valid-api-token') do
      limit = ENV.fetch('RESULTS_THROTTLE_LIMIT', 10).to_i

      # Build up throttle counter
      (limit + 5).times do
        get '/record/test-id'
      end

      # Request with invalid token should be throttled
      get '/record/test-id', params: { format_token: 'wrong-token' }

      # Should be throttled and redirected
      assert_equal 302, status, 'Invalid format token should not bypass throttle'
      assert response.location.include?('/turnstile'), 'Should redirect to Turnstile on throttle'
    end
  end

  test 'valid format token bypasses general req/ip throttle' do
    ClimateControl.modify(FORMAT_TOKEN: 'valid-api-token') do
      limit = ENV.fetch('REQUESTS_PER_PERIOD', 100).to_i

      # Build up throttle counter on a non-free path
      (limit + 5).times do
        get '/style-guide'
      end

      # Request with valid token should bypass throttle
      get '/style-guide', params: { format_token: 'valid-api-token' }

      assert_response :success, 'Valid format token should bypass the general req/ip throttle'
    end
  end

  test 'invalid format token does not bypass general req/ip throttle' do
    ClimateControl.modify(FORMAT_TOKEN: 'valid-api-token') do
      limit = ENV.fetch('REQUESTS_PER_PERIOD', 100).to_i

      # Build up throttle counter
      (limit + 5).times do
        get '/style-guide'
      end

      # Request with invalid token should be throttled
      get '/style-guide', params: { format_token: 'wrong-token' }

      # Should be throttled and redirected
      assert_equal 302, status, 'Invalid format token should not bypass throttle'
      assert response.location.include?('/turnstile'), 'Should redirect to Turnstile on throttle'
    end
  end

  test 'valid format token works when FORMAT_TOKEN env var is not set' do
    # When FORMAT_TOKEN is not set, no token should bypass throttling
    ClimateControl.modify(FORMAT_TOKEN: '') do
      limit = ENV.fetch('REQUESTS_PER_PERIOD', 100).to_i

      # Build up throttle counter
      (limit + 5).times do
        get '/style-guide'
      end

      # Even with a token, it should be throttled because FORMAT_TOKEN is blank
      get '/style-guide', params: { format_token: 'any-token' }

      assert_equal 302, status, 'Token should not bypass throttle when FORMAT_TOKEN env var is not set'
    end
  end
end
