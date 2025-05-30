source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.2.8'

gem 'bootsnap', require: false
gem 'bot_challenge_page'
gem 'graphql'
gem 'graphql-client'
gem 'http'
gem 'importmap-rails'
gem 'jbuilder'
gem 'mitlibraries-theme', git: 'https://github.com/mitlibraries/mitlibraries-theme', tag: 'v1.4'
gem 'puma'
gem 'rack-attack'
gem 'rails', '~> 7.1.0'
gem 'redis'
gem 'sentry-rails'
gem 'sentry-ruby'
gem 'sprockets-rails'
gem 'stimulus-rails'
gem 'turbo-rails'
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

group :production do
  gem 'pg'
end

group :development, :test do
  gem 'debug', platforms: %i[mri mingw x64_mingw]
  gem 'dotenv-rails'
  gem 'sqlite3'
end

group :development do
  gem 'annotate'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'rubocop'
  gem 'rubocop-rails'
  gem 'web-console'
end

group :test do
  gem 'capybara'
  gem 'climate_control'
  gem 'minitest-reporters'
  gem 'mocha'
  gem 'selenium-webdriver'
  gem 'simplecov'
  gem 'simplecov-lcov'
  gem 'vcr'
  gem 'webmock'
end

gem 'flipflop', '~> 2.7'
