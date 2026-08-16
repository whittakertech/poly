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

# Adapter is parameterized so the same suite can run against SQLite (default,
# in-memory) or PostgreSQL -- see README's "Supported Databases" section and
# issue #186. MySQL is not a supported option here: see that section for why.
POLY_TEST_ADAPTER = ENV.fetch('POLY_TEST_ADAPTER', 'sqlite3')

connection_config =
  case POLY_TEST_ADAPTER
  when 'sqlite3'
    { adapter: 'sqlite3', database: ':memory:' }
  when 'postgresql'
    {
      adapter: 'postgresql',
      host: ENV.fetch('POLY_TEST_DB_HOST', 'localhost'),
      port: ENV.fetch('POLY_TEST_DB_PORT', '5432'),
      username: ENV.fetch('POLY_TEST_DB_USER', 'postgres'),
      password: ENV.fetch('POLY_TEST_DB_PASSWORD', 'postgres'),
      database: ENV.fetch('POLY_TEST_DB_NAME', 'poly_test')
    }
  else
    raise "Unsupported POLY_TEST_ADAPTER: #{POLY_TEST_ADAPTER.inspect} " \
          '(supported: sqlite3, postgresql -- see README "Supported Databases")'
  end

ActiveRecord::Base.establish_connection(connection_config)
ActiveRecord::Base.logger = Logger.new(nil)

if POLY_TEST_ADAPTER == 'postgresql'
  # Postgres persists the schema across runs (unlike SQLite's `:memory:`), so
  # drop and rebuild it each run to keep the suite idempotent.
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table, force: :cascade)
  end
end

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

  create_table :statuses do |t|
    t.references :resource, polymorphic: true, null: false
    t.string :resource_role, null: false
    t.string :state, null: false
    t.boolean :is_prime, null: false, default: false
    t.integer :superseded_by_id
    t.timestamps
  end

  add_index :statuses, %i[resource_type resource_id resource_role],
            unique: true, where: 'is_prime', name: 'index_statuses_prime'
end

# Test models
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

class Post < ApplicationRecord
  has_many :comments, as: :commentable
  has_many :taggings, as: :taggable

  # The parent macro (`has_stack`) is the consumer's to write; Poly ships only
  # the card concern. These associations are the wiring a consumer would emit.
  has_many :statuses, -> { for_role('status').order(created_at: :desc) },
           as: :resource, class_name: 'Status'
  has_one :status, -> { for_role('status').prime },
          as: :resource, class_name: 'Status'
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

class Status < ApplicationRecord
  belongs_to :resource, polymorphic: true

  include Poly::Joins
  include Poly::Stack

  poly_stack :resource
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
