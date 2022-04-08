require_relative "boot"

require "rails/all"
require 'sprockets/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TimdexUi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Enable asset pipeline
    config.assets.enabled = true
    config.assets.version = '1.0'
  end
end
