# Explicitly require Feature model to check if bot detection is enabled
require Rails.root.join('app/models/feature')

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
    Feature.enabled?(:bot_detection)
  end
end

TurnstileConfig.apply
