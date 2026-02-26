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
      assert_match 'Turnstile validation failed', response.body
      refute session[:passed_turnstile]
    end
  end

  test 'show returns 404 when feature is disabled' do
    ClimateControl.modify(FEATURE_BOT_DETECTION: 'false') do
      TurnstileConfig.apply
      get turnstile_path
      assert_response :not_found
    ensure
      TurnstileConfig.apply
    end
  end
end
