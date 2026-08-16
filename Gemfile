# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'pg'
gem 'sqlite3'

# CI pins the declared ActiveRecord/Rails version per matrix cell via
# ACTIVERECORD_VERSION (see .github/workflows/ci.yml and issue #186). Left
# unset, Bundler resolves whatever satisfies the gemspec's `>= 7.1` bound
# (currently the latest 8.x). Values track the gemspec's declared support
# window (7.1, 7.2, 8.x) -- keep in sync if that window changes.
case ENV['ACTIVERECORD_VERSION']
when '7.1'
  gem 'activerecord', '~> 7.1.0'
  gem 'activesupport', '~> 7.1.0'
when '7.2'
  gem 'activerecord', '~> 7.2.0'
  gem 'activesupport', '~> 7.2.0'
when '8.x'
  gem 'activerecord', '>= 8.0'
  gem 'activesupport', '>= 8.0'
end

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
