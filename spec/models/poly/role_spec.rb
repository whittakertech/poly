# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Poly::Role do
  describe 'validations' do
    it 'is valid with a conforming role' do
      tagging = build(:tagging, taggable_role: 'primary')

      expect(tagging).to be_valid
    end

    it 'is invalid without a role' do
      tagging = build(:tagging, taggable_role: nil)

      expect(tagging).not_to be_valid
      expect(tagging.errors[:taggable_role]).to include("can't be blank")
    end

    it 'accepts uppercase characters after normalization downcases them' do
      tagging = build(:tagging, taggable_role: 'Primary')

      expect(tagging).to be_valid
      expect(tagging.taggable_role).to eq('primary')
    end

    it 'is invalid with spaces' do
      tagging = build(:tagging, taggable_role: 'my role')

      expect(tagging).not_to be_valid
      expect(tagging.errors[:taggable_role]).to include('is invalid')
    end

    it 'is invalid with special characters' do
      tagging = build(:tagging, taggable_role: 'role-name')

      expect(tagging).not_to be_valid
    end

    it 'allows underscores and digits' do
      tagging = build(:tagging, taggable_role: 'role_123')

      expect(tagging).to be_valid
    end

    it 'is invalid when exceeding max length' do
      tagging = build(:tagging, taggable_role: 'a' * 65)

      expect(tagging).not_to be_valid
      expect(tagging.errors[:taggable_role]).to include(/too long/)
    end

    it 'allows roles up to max length' do
      tagging = build(:tagging, taggable_role: 'a' * 64)

      expect(tagging).to be_valid
    end
  end

  describe 'normalization' do
    it 'strips whitespace before validation' do
      tagging = build(:tagging, taggable_role: '  primary  ')
      tagging.valid?

      expect(tagging.taggable_role).to eq('primary')
    end

    it 'downcases before validation' do
      tagging = build(:tagging, taggable_role: 'PRIMARY')
      tagging.valid?

      expect(tagging.taggable_role).to eq('primary')
    end

    it 'strips and downcases combined' do
      tagging = build(:tagging, taggable_role: '  My_Role  ')
      tagging.valid?

      expect(tagging.taggable_role).to eq('my_role')
    end
  end

  describe '.for_role' do
    it 'scopes records by role' do
      primary = create(:tagging, taggable_role: 'primary')
      create(:tagging, taggable_role: 'secondary')

      results = Tagging.for_role('primary')

      expect(results).to contain_exactly(primary)
    end

    it 'returns empty relation when no matches' do
      create(:tagging, taggable_role: 'primary')

      results = Tagging.for_role('nonexistent')

      expect(results).to be_empty
    end
  end
end
