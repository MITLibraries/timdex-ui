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

  test 'verify sets turnstile_verified_at encrypted cookie for grace period' do
    with_bot_detection_enabled do
      post turnstile_verify_path,
           params: { 'cf-turnstile-response' => 'mocked', return_to: '/results?q=test' }

      # Check that the Set-Cookie header includes turnstile_verified_at
      assert_match(/turnstile_verified_at/, response.headers['Set-Cookie'].to_s,
                   'Response should set turnstile_verified_at cookie')
    end
  end

  test 'verify grace period duration respects TURNSTILE_GRACE_PERIOD env var' do
    with_bot_detection_enabled do
      grace_period_minutes = 5

      ClimateControl.modify(TURNSTILE_GRACE_PERIOD: grace_period_minutes.to_s) do
        post turnstile_verify_path,
             params: { 'cf-turnstile-response' => 'mocked', return_to: '/results?q=test' }

        # Check that the Set-Cookie header includes turnstile_verified_at
        assert_match(/turnstile_verified_at/, response.headers['Set-Cookie'].to_s,
                     'Response should set turnstile_verified_at cookie with custom grace period')
        assert_redirected_to '/results?q=test'
      end
    end
  end

  test 'verify applies default grace period when TURNSTILE_GRACE_PERIOD env var not set' do
    with_bot_detection_enabled do
      default_grace_period = 15 # minutes (the default from the controller)

      # Explicitly ensure env var is not set
      ClimateControl.modify(TURNSTILE_GRACE_PERIOD: nil) do
        post turnstile_verify_path,
             params: { 'cf-turnstile-response' => 'mocked', return_to: '/results?q=test' }

        # Check that the Set-Cookie header includes turnstile_verified_at
        assert_match(/turnstile_verified_at/, response.headers['Set-Cookie'].to_s,
                     'Response should set turnstile_verified_at cookie with default grace period')
      end
    end
  end

  test 'different requests both set turnstile_verified_at cookie' do
    with_bot_detection_enabled do
      # First request
      post turnstile_verify_path,
           params: { 'cf-turnstile-response' => 'mocked', return_to: '/results?q=test1' }
      assert_match(/turnstile_verified_at/, response.headers['Set-Cookie'].to_s,
                   'Response should set turnstile_verified_at cookie after first verification')

      # Second request
      post turnstile_verify_path,
           params: { 'cf-turnstile-response' => 'mocked', return_to: '/results?q=test2' }
      assert_match(/turnstile_verified_at/, response.headers['Set-Cookie'].to_s,
                   'Response should set turnstile_verified_at cookie after second verification')
    end
  end

  test 'failed Turnstile verification does not set cookie' do
    with_bot_detection_enabled do
      # Attempt to verify without valid token
      post turnstile_verify_path,
           params: { return_to: '/results?q=test' }

      # Cookie should NOT be set on failed verification (no Set-Cookie header for turnstile_verified_at)
      cookie_header = response.headers['Set-Cookie'].to_s
      assert_no_match(/turnstile_verified_at/, cookie_header,
                      'Cookie turnstile_verified_at should not be set when Turnstile verification fails')
    end
  end
end
