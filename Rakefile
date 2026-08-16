# frozen_string_literal: true

require 'bundler/setup'
require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

require 'yard'
namespace :docs do
  YARD::Rake::YardocTask.new(:api)
end

task default: :spec
