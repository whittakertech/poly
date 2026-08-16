# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Poly::PolymorphicJoinError do
  it 'is a StandardError' do
    expect(described_class.ancestors).to include(StandardError)
  end

  it 'keeps the deprecated top-level PolymorphicJoinError as an alias to the same class object' do
    expect(defined?(PolymorphicJoinError)).to eq('constant')
    expect(PolymorphicJoinError).to equal(described_class)
  end
end
