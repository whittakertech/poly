# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'pg'

# sqlite3 2.x requires ActiveRecord 7.2+. Rails 6.1's SQLite3Adapter declares
# `gem 'sqlite3', '~> 1.4'` at load time, so the 6.1 lane must stay on 1.x or
# `establish_connection` raises Gem::LoadError.
if ENV['ACTIVERECORD_VERSION'] == '6.1'
  gem 'sqlite3', '~> 1.4'
else
  gem 'sqlite3'
end

# CI pins the declared ActiveRecord/Rails version per matrix cell via
# ACTIVERECORD_VERSION (see .github/workflows/ci.yml and issue #186). Left
# unset, Bundler resolves whatever satisfies the gemspec's `>= 6.1` bound
# (currently the latest 8.x). Values track the gemspec's declared support
# window (6.1, 7.1, 7.2, 8.x) -- keep in sync if that window changes.
#
# 6.1 exists for hellodancerrails (Rails 6.1.7.10 / Ruby 3.3.11), which needs
# Poly via Midas. Rails 6.1 is only exercised on Ruby 3.3 -- see the matrix
# excludes in the CI workflows.
case ENV['ACTIVERECORD_VERSION']
when '6.1'
  gem 'activerecord', '~> 6.1.0'
  gem 'activesupport', '~> 6.1.0'
  # concurrent-ruby 1.3.5 removed its implicit `require 'logger'`, which
  # ActiveSupport 6.1 depends on -- without this pin `require 'active_record'`
  # raises `NameError: uninitialized constant
  # ActiveSupport::LoggerThreadSafeLevel::Logger`. Rails 7.1+ requires logger
  # itself, so this is scoped to the 6.1 lane. hellodancerrails, the consumer
  # this lane exists for, carries the same pin (concurrent-ruby 1.3.4).
  gem 'concurrent-ruby', '< 1.3.5'
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
  # rake itself isn't declared anywhere pre-existing in the bundle (CI invokes
  # `bundle exec rspec`/`bundle exec rubocop` directly, never `bundle exec
  # rake`), so `bundle exec rake docs:api` fails with "rake is not currently
  # included in the bundle" without this. Needed to make the Rakefile's tasks
  # (pre-existing `spec`/`default` and the new `docs:api`) actually runnable
  # via `bundle exec rake`.
  gem 'rake', require: false

  # Pin the lint toolchain so CI is reproducible; bump deliberately.
  gem 'rubocop', '~> 1.88.0', require: false
  gem 'rubocop-factory_bot', '~> 2.28.0', require: false
  gem 'rubocop-rails', '~> 2.35.0', require: false
  gem 'rubocop-rspec', '~> 3.10.0', require: false
  gem 'yard', '~> 0.9.45', require: false
end
