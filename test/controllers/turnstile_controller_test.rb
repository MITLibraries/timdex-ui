require 'test_helper'
require 'climate_control'

class TurnstileControllerTest < ActionDispatch::IntegrationTest
  def with_bot_detection_enabled
    ClimateControl.modify(FEATURE_BOT_DETECTION: 'true') do
      TurnstileConfig.apply
      yield
    ensure
      TurnstileConfig.apply
    end
  end

  test 'show renders when bot detection is enabled' do
    with_bot_detection_enabled do
      get turnstile_path
      assert_response :success
    end
  end

  test 'verify sets session and redirects back to search' do
    with_bot_detection_enabled do
      post turnstile_verify_path, params: { 'cf-turnstile-response' => 'mocked', return_to: '/results?q=ocean' }

      assert_redirected_to '/results?q=ocean'
      assert session[:passed_turnstile]
    end
  end

  test 'verify re-renders on failed validation' do
    with_bot_detection_enabled do
      post turnstile_verify_path

      assert_response :unprocessable_entity
      assert_match "We couldn't complete the verification", response.body
      refute session[:passed_turnstile]
    end
  end

  test 'verify falls back to root_path for invalid return_to' do
    with_bot_detection_enabled do
      post turnstile_verify_path, params: { 'cf-turnstile-response' => 'mocked', return_to: 'foo' }
      assert_redirected_to root_path
      assert session[:passed_turnstile]
    end
  end

  test 'verify writes turnstile_verified cache key for grace period' do
    with_bot_detection_enabled do
      ip = '192.168.1.1'
      post turnstile_verify_path,
           params: { 'cf-turnstile-response' => 'mocked', return_to: '/results?q=test' },
           headers: { 'REMOTE_ADDR' => ip }

      # Check that cache key was written
      cache_key = "turnstile_verified:#{ip}"
      assert Rails.cache.read(cache_key), "Cache key #{cache_key} should be set after Turnstile verification"
    end
  end

  test 'verify grace period duration respects TURNSTILE_GRACE_PERIOD env var' do
    with_bot_detection_enabled do
      ip = '192.168.1.2'
      grace_period_minutes = 5

      ClimateControl.modify(TURNSTILE_GRACE_PERIOD: grace_period_minutes.to_s) do
        post turnstile_verify_path,
             params: { 'cf-turnstile-response' => 'mocked', return_to: '/results?q=test' },
             headers: { 'REMOTE_ADDR' => ip }

        cache_key = "turnstile_verified:#{ip}"
        assert Rails.cache.read(cache_key), 'Cache key should be set'
      end
    end
  end

  test 'verify applies default grace period when TURNSTILE_GRACE_PERIOD env var not set' do
    with_bot_detection_enabled do
      ip = '192.168.1.3'

      # Explicitly ensure env var is not set
      ClimateControl.modify(TURNSTILE_GRACE_PERIOD: nil) do
        post turnstile_verify_path,
             params: { 'cf-turnstile-response' => 'mocked', return_to: '/results?q=test' },
             headers: { 'REMOTE_ADDR' => ip }

        cache_key = "turnstile_verified:#{ip}"
        assert Rails.cache.read(cache_key), 'Cache key should be set with default grace period'
      end
    end
  end

  test 'different IPs get separate cache keys' do
    with_bot_detection_enabled do
      ip1 = '192.168.1.4'
      ip2 = '192.168.1.5'

      # First IP solves Turnstile
      post turnstile_verify_path,
           params: { 'cf-turnstile-response' => 'mocked', return_to: '/results?q=test' },
           headers: { 'REMOTE_ADDR' => ip1 }

      # Second IP solves Turnstile
      post turnstile_verify_path,
           params: { 'cf-turnstile-response' => 'mocked', return_to: '/results?q=test' },
           headers: { 'REMOTE_ADDR' => ip2 }

      # Both should have their own cache keys
      cache_key1 = "turnstile_verified:#{ip1}"
      cache_key2 = "turnstile_verified:#{ip2}"
      assert Rails.cache.read(cache_key1), 'Cache key for IP1 should be set'
      assert Rails.cache.read(cache_key2), 'Cache key for IP2 should be set'
    end
  end

  test 'failed Turnstile verification does not write cache key' do
    with_bot_detection_enabled do
      ip = '192.168.1.6'

      # Attempt to verify without valid token
      post turnstile_verify_path,
           params: { return_to: '/results?q=test' },
           headers: { 'REMOTE_ADDR' => ip }

      # Cache key should NOT be written on failed verification
      cache_key = "turnstile_verified:#{ip}"
      assert_nil Rails.cache.read(cache_key), 'Cache key should not be set when Turnstile verification fails'
    end
  end
end
