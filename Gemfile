# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'sqlite3'

group :development, :test do
  gem 'factory_bot'
  gem 'rspec'
  gem 'simplecov', require: false
  gem 'simplecov-console', require: false
end

group :development do
  # Pin the lint toolchain so CI is reproducible; bump deliberately.
  gem 'rubocop', '~> 1.88.0', require: false
  gem 'rubocop-factory_bot', '~> 2.28.0', require: false
  gem 'rubocop-rails', '~> 2.35.0', require: false
  gem 'rubocop-rspec', '~> 3.10.0', require: false
end
