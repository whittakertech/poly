# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  require 'simplecov-console'

  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
    [SimpleCov::Formatter::HTMLFormatter, SimpleCov::Formatter::Console]
  )

  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/lib/poly/version.rb'
    track_files 'lib/**/*.rb'
  end
end

require 'active_record'
require 'poly'
require 'factory_bot'

# In-memory SQLite database
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Base.logger = Logger.new(nil)

# Schema
ActiveRecord::Schema.define do
  create_table :posts do |t|
    t.string :title
    t.timestamps
  end

  create_table :users do |t|
    t.string :name
    t.timestamps
  end

  create_table :accounts do |t|
    t.string :name
    t.timestamps
  end

  create_table :ledgers do |t|
    t.references :account, null: false
    t.timestamps
  end

  create_table :comments do |t|
    t.text :body
    t.references :commentable, polymorphic: true, null: false
    t.timestamps
  end

  create_table :taggings do |t|
    t.references :taggable, polymorphic: true, null: false
    t.string :taggable_role, null: false
    t.timestamps
  end

  create_table :coins do |t|
    t.references :ledger, null: false
    t.references :resource, polymorphic: true, null: false
    t.string :resource_role, null: false
    t.integer :owner_id
    t.string :owner_type
    t.timestamps
  end
end

# Test models
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

class Post < ApplicationRecord
  has_many :comments, as: :commentable
  has_many :taggings, as: :taggable
end

class User < ApplicationRecord
  has_many :comments, as: :commentable
  has_many :taggings, as: :taggable
end

class Account < ApplicationRecord
  has_many :ledgers
end

class Ledger < ApplicationRecord
  belongs_to :account
  has_many :coins
end

class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true

  include Poly::Joins
end

class Tagging < ApplicationRecord
  belongs_to :taggable, polymorphic: true

  include Poly::Role

  poly_role :taggable
end

class Coin < ApplicationRecord
  belongs_to :ledger
  belongs_to :resource, polymorphic: true

  include Poly::Owners

  poly_owner :resource, owner: -> { ledger&.account }
end

# Load factories
Dir[File.join(__dir__, 'factories', '**', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
