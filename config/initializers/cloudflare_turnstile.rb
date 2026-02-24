module TurnstileConfig
  module_function

  def apply
    RailsCloudflareTurnstile.reset_configuration!
    enabled = bot_detection_enabled?
    enabled = false if Rails.env.test?

    RailsCloudflareTurnstile.configure do |config|
      config.site_key = ENV['TURNSTILE_SITEKEY']
      config.secret_key = ENV['TURNSTILE_SECRET']
      config.enabled = enabled
      config.fail_open = !enabled
      config.mock_enabled = Rails.env.test?
    end
  end

  def bot_detection_enabled?
    if defined?(Feature)
      Feature.enabled?(:bot_detection)
    else
      ENV.fetch('FEATURE_BOT_DETECTION', false).to_s.downcase == 'true'
    end
  end
end

TurnstileConfig.apply
