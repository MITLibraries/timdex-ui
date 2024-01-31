require_relative "boot"

require "rails/all"
require 'sprockets/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TimdexUi
  class Application < Rails::Application
    # Before filter for Flipflop dashboard. Replace with a lambda or method name
    # defined in ApplicationController to implement access control.
    config.flipflop.dashboard_access_filter = -> { head :forbidden }

    # By default, when set to `nil`, strategy loading errors are suppressed in test
    # mode. Set to `true` to always raise errors, or `false` to always warn.
    config.flipflop.raise_strategy_errors = nil

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Enable asset pipeline
    config.assets.enabled = true
    config.assets.version = '1.0'
  end
end
