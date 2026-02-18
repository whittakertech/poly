# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Poly::Owners do
  describe 'owner assignment callback' do
    it 'assigns owner_type and owner_id before validation from owner proc' do
      coin = create(:coin)

      coin.valid?

      expect(coin.owner_type).to eq('Account')
      expect(coin.owner_id).to eq(coin.ledger.account.id)
    end

    it 'clears owner columns when owner resolves to nil' do
      ledger = build(:ledger, account: nil)
      coin = build(:coin, ledger: ledger, owner_type: 'Account', owner_id: 10)

      coin.valid?

      expect(coin.owner_type).to be_nil
      expect(coin.owner_id).to be_nil
    end

    it 'raises when owner resolves to a non-active-record value' do
      stub_const('InvalidOwnerCoin', Class.new(ApplicationRecord) do
        self.table_name = 'coins'

        belongs_to :ledger
        belongs_to :resource, polymorphic: true

        include Poly::Owners

        poly_owner :resource, owner: -> { 'invalid' }
      end)

      coin = InvalidOwnerCoin.new(ledger: create(:ledger), resource: create(:post), resource_role: 'primary')

      expect { coin.valid? }.to raise_error(ArgumentError, /owner must resolve to an ActiveRecord::Base/)
    end

    it 'raises when owner option is missing' do
      expect do
        stub_const('MissingOwnerCoin', Class.new(ApplicationRecord) do
          self.table_name = 'coins'

          include Poly::Owners

          poly_owner :resource, owner: nil
        end)
      end.to raise_error(ArgumentError, /owner is required/)
    end

    it 'assigns owner from a Symbol method name' do
      stub_const('SymbolOwnerCoin', Class.new(ApplicationRecord) do
        self.table_name = 'coins'
        belongs_to :ledger
        belongs_to :resource, polymorphic: true
        include Poly::Owners

        poly_owner :resource, owner: :ledger
      end)
      coin = SymbolOwnerCoin.new(ledger: create(:ledger), resource: create(:post), resource_role: 'primary')
      coin.valid?
      expect(coin).to have_attributes(owner_type: 'Ledger', owner_id: coin.ledger.id)
    end

    it 'assigns owner from a direct ActiveRecord instance' do
      account = create(:account)
      stub_const('DirectOwnerCoin', Class.new(ApplicationRecord) do
        self.table_name = 'coins'
        belongs_to :ledger
        belongs_to :resource, polymorphic: true
        include Poly::Owners

        poly_owner :resource, owner: account
      end)
      coin = DirectOwnerCoin.create!(ledger: create(:ledger), resource: create(:post), resource_role: 'primary')
      expect(coin).to have_attributes(owner_type: 'Account', owner_id: account.id)
    end

    it 'raises when the owner is not persisted' do
      unpersisted = build(:account)
      stub_const('UnpersistedOwnerCoin', Class.new(ApplicationRecord) do
        self.table_name = 'coins'
        belongs_to :ledger
        belongs_to :resource, polymorphic: true
        include Poly::Owners

        poly_owner :resource, owner: -> { unpersisted }
      end)
      coin = UnpersistedOwnerCoin.new(ledger: create(:ledger), resource: create(:post), resource_role: 'primary')
      expect { coin.valid? }.to raise_error(ArgumentError, /owner must be persisted/)
    end

    it 'raises when owner resolves to nil and allow_nil is false' do
      stub_const('StrictOwnerCoin', Class.new(ApplicationRecord) do
        self.table_name = 'coins'
        belongs_to :ledger
        belongs_to :resource, polymorphic: true
        include Poly::Owners

        poly_owner :resource, owner: -> {}, allow_nil: false
      end)
      coin = StrictOwnerCoin.new(ledger: create(:ledger), resource: create(:post), resource_role: 'primary')
      expect { coin.valid? }.to raise_error(ArgumentError, /owner resolved to nil/)
    end
  end

  describe 'immutability' do
    it 'prevents owner changes on update when immutable: true' do
      stub_const('ImmutableCoin', Class.new(ApplicationRecord) do
        self.table_name = 'coins'
        belongs_to :ledger
        belongs_to :resource, polymorphic: true
        include Poly::Owners

        poly_owner :resource, owner: -> { ledger&.account }, immutable: true
      end)
      coin = ImmutableCoin.create!(ledger: create(:ledger), resource: create(:post), resource_role: 'primary')
      coin.ledger = create(:ledger)
      expect(coin).not_to be_valid
    end
  end

  describe 'association validation' do
    it 'raises when the named association is not polymorphic' do
      expect do
        stub_const('BadAssocCoin', Class.new(ApplicationRecord) do
          self.table_name = 'coins'
          belongs_to :ledger
          include Poly::Owners

          poly_owner :ledger, owner: -> { ledger&.account }
        end)
      end.to raise_error(ArgumentError, /must declare belongs_to.*polymorphic/)
    end

    it 'raises when the named association does not exist' do
      expect do
        stub_const('NoAssocCoin', Class.new(ApplicationRecord) do
          self.table_name = 'coins'
          include Poly::Owners

          poly_owner :nonexistent, owner: -> {}
        end)
      end.to raise_error(ArgumentError, /must declare belongs_to.*polymorphic/)
    end
  end
end
