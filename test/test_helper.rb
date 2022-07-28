ENV['RAILS_ENV'] ||= 'test'
require 'simplecov'
require 'simplecov-lcov'
SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
SimpleCov::Formatter::LcovFormatter.config.lcov_file_name = 'coverage.lcov'
SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov.formatter = SimpleCov::Formatter::LcovFormatter
]
SimpleCov.start('rails')
require_relative '../config/environment'
require 'rails/test_help'
require 'mocha/minitest'

VCR.configure do |config|
  config.ignore_localhost = true
  config.cassette_library_dir = 'test/vcr_cassettes'
  config.hook_into :webmock
  config.allow_http_connections_when_no_cassette = false
  config.filter_sensitive_data('FAKE_TIMDEX_HOST') { ENV.fetch('TIMDEX_HOST').to_s }
  config.filter_sensitive_data('http://FAKE_TIMDEX_HOST/graphql/') { ENV.fetch('TIMDEX_GRAPHQL').to_s }
  config.filter_sensitive_data('FAKE_TIMDEX_INDEX') { ENV.fetch('TIMDEX_INDEX').to_s }
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
