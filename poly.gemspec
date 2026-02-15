# frozen_string_literal: true

require_relative 'lib/poly/version'

Gem::Specification.new do |spec|
  spec.name = 'poly'
  spec.version = Poly::VERSION
  spec.authors = ['Lee Whittaker']
  spec.email = ['lee@whittakertech.com']

  spec.summary = 'Polymorphic association utilities for ActiveRecord'
  spec.description = 'Type-safe joins and labeled identity for polymorphic belongs_to associations.'
  spec.homepage = 'https://github.com/leewhittaker/poly'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.4.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*', 'Rakefile', 'README.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 7.1'
  spec.add_dependency 'activesupport', '>= 7.1'
end
