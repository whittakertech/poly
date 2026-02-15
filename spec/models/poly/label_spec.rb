# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Poly::Label do
  describe 'validations' do
    it 'is valid with a conforming label' do
      tagging = build(:tagging, taggable_label: 'primary')

      expect(tagging).to be_valid
    end

    it 'is invalid without a label' do
      tagging = build(:tagging, taggable_label: nil)

      expect(tagging).not_to be_valid
      expect(tagging.errors[:taggable_label]).to include("can't be blank")
    end

    it 'accepts uppercase characters after normalization downcases them' do
      tagging = build(:tagging, taggable_label: 'Primary')

      expect(tagging).to be_valid
      expect(tagging.taggable_label).to eq('primary')
    end

    it 'is invalid with spaces' do
      tagging = build(:tagging, taggable_label: 'my label')

      expect(tagging).not_to be_valid
      expect(tagging.errors[:taggable_label]).to include('is invalid')
    end

    it 'is invalid with special characters' do
      tagging = build(:tagging, taggable_label: 'label-name')

      expect(tagging).not_to be_valid
    end

    it 'allows underscores and digits' do
      tagging = build(:tagging, taggable_label: 'label_123')

      expect(tagging).to be_valid
    end

    it 'is invalid when exceeding max length' do
      tagging = build(:tagging, taggable_label: 'a' * 65)

      expect(tagging).not_to be_valid
      expect(tagging.errors[:taggable_label]).to include(/too long/)
    end

    it 'allows labels up to max length' do
      tagging = build(:tagging, taggable_label: 'a' * 64)

      expect(tagging).to be_valid
    end
  end

  describe 'normalization' do
    it 'strips whitespace before validation' do
      tagging = build(:tagging, taggable_label: '  primary  ')
      tagging.valid?

      expect(tagging.taggable_label).to eq('primary')
    end

    it 'downcases before validation' do
      tagging = build(:tagging, taggable_label: 'PRIMARY')
      tagging.valid?

      expect(tagging.taggable_label).to eq('primary')
    end

    it 'strips and downcases combined' do
      tagging = build(:tagging, taggable_label: '  My_Label  ')
      tagging.valid?

      expect(tagging.taggable_label).to eq('my_label')
    end
  end

  describe '.for_label' do
    it 'scopes records by label' do
      primary = create(:tagging, taggable_label: 'primary')
      create(:tagging, taggable_label: 'secondary')

      results = Tagging.for_label('primary')

      expect(results).to contain_exactly(primary)
    end

    it 'returns empty relation when no matches' do
      create(:tagging, taggable_label: 'primary')

      results = Tagging.for_label('nonexistent')

      expect(results).to be_empty
    end
  end
end
