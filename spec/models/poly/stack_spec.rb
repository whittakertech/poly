# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Poly::Stack do
  let(:post) { create(:post) }

  describe 'priming' do
    it 'makes the first card prime' do
      card = create(:status, resource: post, state: 'draft')

      expect(card.is_prime).to be(true)
    end

    it 'promotes the newest card and demotes the previous prime' do
      first  = create(:status, resource: post, state: 'draft')
      second = create(:status, resource: post, state: 'public')

      expect(second.reload.is_prime).to be(true)
      expect(first.reload.is_prime).to be(false)
    end

    it 'keeps exactly one prime per resource and role' do
      create(:status, resource: post, state: 'draft')
      create(:status, resource: post, state: 'public')
      create(:status, resource: post, state: 'trash')

      primes = Status.where(resource: post, resource_role: 'status').prime

      expect(primes.count).to eq(1)
      expect(primes.first.state).to eq('trash')
    end
  end

  describe 'supersession chain' do
    it 'links the demoted card forward to its successor' do
      first  = create(:status, resource: post, state: 'draft')
      second = create(:status, resource: post, state: 'public')

      expect(first.reload.superseded_by_id).to eq(second.id)
      expect(second.reload.superseded_by_id).to be_nil
    end
  end

  describe 'independence' do
    it 'maintains a separate prime per role on the same resource' do
      status     = create(:status, resource: post, resource_role: 'status', state: 'public')
      visibility = create(:status, resource: post, resource_role: 'visibility', state: 'listed')

      expect(status.reload.is_prime).to be(true)
      expect(visibility.reload.is_prime).to be(true)
    end

    it 'maintains a separate prime per resource' do
      other = create(:post)
      mine  = create(:status, resource: post, state: 'public')
      yours = create(:status, resource: other, state: 'draft')

      expect(mine.reload.is_prime).to be(true)
      expect(yours.reload.is_prime).to be(true)
    end
  end

  # The `prime` scope + Poly::Role's `for_role` compose into the parent-side
  # associations a consumer wires (see spec_helper's Post) — this guards that.
  describe 'parent associations' do
    it 'reaches the current prime through a role-scoped has_one' do
      post.statuses.create!(state: 'draft')
      post.statuses.create!(state: 'public')

      expect(post.reload.status.state).to eq('public')
    end

    it 'reaches the whole stack through a role-scoped has_many' do
      post.statuses.create!(state: 'draft')
      post.statuses.create!(state: 'public')

      expect(post.reload.statuses.map(&:state)).to match_array(%w[draft public])
    end
  end
end
