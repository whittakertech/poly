# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Poly::Migration do
  let(:connection) { ActiveRecord::Base.connection }

  # PostgreSQL's `pg_get_expr` echoes a compound predicate back wrapped in
  # parens (e.g. `(owner_type IS NOT NULL)`); SQLite doesn't. Strip a single
  # pair of wrapping parens so `index.where` assertions hold on both adapters.
  def unwrap_where(clause)
    clause.to_s.sub(/\A\((.*)\)\z/, '\1')
  end

  describe 'table builder helpers' do
    let(:table_name) { :poly_migration_builders }

    after do
      connection.drop_table(table_name, if_exists: true)
    end

    it 'adds resource, role, owner columns and indexes in create_table' do
      migration = Class.new(ActiveRecord::Migration[7.1]) do
        include Poly::Migration

        def change
          create_table :poly_migration_builders do |t|
            poly_resource t, :resource, null: false
            poly_role t, :resource, null: false
            poly_owner t, null: false
          end

          poly_resource_index :poly_migration_builders, :resource, unique: true
          poly_owner_index :poly_migration_builders
        end
      end.new

      migration.migrate(:up)

      columns = connection.columns(table_name).index_by(&:name)
      expect(columns.fetch('resource_type').null).to be(false)
      expect(columns.fetch('resource_id').type).to eq(:string)
      expect(columns.fetch('resource_role').null).to be(false)
      expect(columns.fetch('owner_type').null).to be(false)
      expect(columns.fetch('owner_id').type).to eq(:string)

      indexes = connection.indexes(table_name)
      expect(indexes.any? { |index| index.columns == %w[resource_type resource_id] && index.unique }).to be(true)
      expect(indexes.any? { |index| index.columns == %w[owner_type owner_id] && !index.unique }).to be(true)
    end

    it 'works when called inside change_table' do
      connection.create_table(table_name, force: true) { |_t| nil }

      migration = Class.new(ActiveRecord::Migration[7.1]) do
        include Poly::Migration

        def change
          change_table :poly_migration_builders do |t|
            poly_resource t, :subject, null: false
            poly_role t, :subject, null: false
            poly_owner t, type_column: :account_type, id_column: :account_id, null: false
          end
        end
      end.new

      migration.migrate(:up)

      columns = connection.columns(table_name).index_by(&:name)
      expect(columns.fetch('subject_type').null).to be(false)
      expect(columns.fetch('subject_id').type).to eq(:string)
      expect(columns.fetch('subject_role').null).to be(false)
      expect(columns.fetch('account_type').null).to be(false)
      expect(columns.fetch('account_id').type).to eq(:string)
    end
  end

  describe 'add_column helpers' do
    let(:table_name) { :poly_migration_add_columns }

    before do
      connection.create_table(table_name, force: true) { |_t| nil }
    end

    after do
      connection.drop_table(table_name, if_exists: true)
    end

    it 'adds resource, role, owner columns and indexes to an existing table' do
      migration = Class.new(ActiveRecord::Migration[7.1]) do
        include Poly::Migration

        def change
          poly_resource :poly_migration_add_columns, :subject, null: false
          poly_role :poly_migration_add_columns, :subject, null: false
          poly_owner :poly_migration_add_columns, null: false

          poly_resource_index :poly_migration_add_columns, :subject
          poly_owner_index :poly_migration_add_columns, unique: true
        end
      end.new

      migration.migrate(:up)

      columns = connection.columns(table_name).index_by(&:name)
      expect(columns.fetch('subject_type').null).to be(false)
      expect(columns.fetch('subject_id').type).to eq(:string)
      expect(columns.fetch('subject_role').null).to be(false)
      expect(columns.fetch('owner_type').null).to be(false)
      expect(columns.fetch('owner_id').type).to eq(:string)

      indexes = connection.indexes(table_name)
      expect(indexes.any? { |index| index.columns == %w[subject_type subject_id] && !index.unique }).to be(true)
      expect(indexes.any? { |index| index.columns == %w[owner_type owner_id] && index.unique }).to be(true)
    end

    it 'supports custom id and owner columns in add_column style' do
      migration = Class.new(ActiveRecord::Migration[7.1]) do
        include Poly::Migration

        def change
          poly_resource :poly_migration_add_columns, :ledgerable, id_type: :integer
          poly_owner :poly_migration_add_columns,
                     type_column: :tenant_type,
                     id_column: :tenant_id,
                     id_type: :integer
        end
      end.new

      migration.migrate(:up)

      columns = connection.columns(table_name).index_by(&:name)
      expect(columns.fetch('ledgerable_id').type).to eq(:integer)
      expect(columns.fetch('tenant_type').type).to eq(:string)
      expect(columns.fetch('tenant_id').type).to eq(:integer)
    end
  end

  describe 'where: passthrough on index helpers' do
    let(:table_name) { :poly_migration_where_indexes }

    before do
      connection.create_table(table_name, force: true) do |t|
        t.string :resource_type
        t.string :resource_id
        t.string :resource_role
        t.boolean :is_prime, default: false
        t.string :owner_type
        t.string :owner_id
      end
    end

    after do
      connection.drop_table(table_name, if_exists: true)
    end

    it 'applies a partial where clause to poly_resource_index' do
      migration = Class.new(ActiveRecord::Migration[7.1]) do
        include Poly::Migration

        def change
          poly_resource_index :poly_migration_where_indexes, :resource, where: 'is_prime'
        end
      end.new

      migration.migrate(:up)

      index = connection.indexes(table_name).find { |i| i.columns == %w[resource_type resource_id] }
      expect(unwrap_where(index.where)).to eq('is_prime')
    end

    it 'applies a partial where clause to poly_owner_index' do
      migration = Class.new(ActiveRecord::Migration[7.1]) do
        include Poly::Migration

        def change
          poly_owner_index :poly_migration_where_indexes, where: 'owner_type IS NOT NULL'
        end
      end.new

      migration.migrate(:up)

      index = connection.indexes(table_name).find { |i| i.columns == %w[owner_type owner_id] }
      expect(unwrap_where(index.where)).to eq('owner_type IS NOT NULL')
    end

    it 'supports an index_name override alongside where and unique' do
      migration = Class.new(ActiveRecord::Migration[7.1]) do
        include Poly::Migration

        def change
          poly_resource_index :poly_migration_where_indexes, :resource,
                              unique: true, where: 'is_prime', index_name: 'index_custom_prime'
        end
      end.new

      migration.migrate(:up)

      index = connection.indexes(table_name).find { |i| i.name == 'index_custom_prime' }
      expect(index).not_to be_nil
      expect(index.unique).to be(true)
      expect(unwrap_where(index.where)).to eq('is_prime')
    end
  end

  describe 'poly_prime_index' do
    let(:table_name) { :poly_migration_prime }

    before do
      connection.create_table(table_name, force: true) do |t|
        t.string :resource_type
        t.string :resource_id
        t.string :resource_role
        t.boolean :is_prime, default: false
      end
    end

    after do
      connection.drop_table(table_name, if_exists: true)
    end

    it 'creates a partial unique index on type/id/role, keeping the pre-refactor index name' do
      migration = Class.new(ActiveRecord::Migration[7.1]) do
        include Poly::Migration

        def change
          poly_prime_index :poly_migration_prime, :resource
        end
      end.new

      migration.migrate(:up)

      index = connection.indexes(table_name).find { |i| i.name == 'index_poly_migration_prime_prime' }
      expect(index).not_to be_nil
      expect(index.columns).to eq(%w[resource_type resource_id resource_role])
      expect(index.unique).to be(true)
      expect(unwrap_where(index.where)).to eq('is_prime')
    end
  end
end
