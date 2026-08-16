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

  # These specs demonstrate the *mechanism* the ticket asks to document: that
  # the partial unique index — not `poly_stack_seize_prime`'s demote step —
  # is what actually enforces "at most one prime per (resource, role)" when
  # two writers race. We construct the race window directly (a second row
  # reaching INSERT with is_prime: true without going through the callback's
  # demote-then-insert serialization), rather than relying on OS-level
  # thread/connection concurrency. A genuinely concurrent (multi-thread,
  # multi-connection) reproduction depends on Postgres in CI (see #186) — the
  # spec_helper's single-connection, in-memory SQLite database can't produce
  # true interleaving, so that reproduction is out of scope here.
  describe 'concurrency boundary' do
    # Simulate the losing side of a race: a second writer whose row also
    # reached INSERT with is_prime: true for the same (resource, role),
    # without going through poly_stack_seize_prime (so the first row is
    # never demoted). `insert_all!` bypasses callbacks (and validations —
    # deliberately, that's the point: we're proving the *index* is the
    # enforcement mechanism, independent of any app-level callback) — this
    # is exactly the "both writers demoted the same prior prime and both
    # attempt insert with is_prime: true" race window from the ticket,
    # constructed directly rather than via real thread interleaving.
    # rubocop:disable Rails/SkipsModelValidations
    def insert_rival_prime(resource:, role:, state:)
      Status.insert_all!([{
                           resource_type: resource.class.name,
                           resource_id: resource.id,
                           resource_role: role,
                           state: state,
                           is_prime: true,
                           created_at: Time.current,
                           updated_at: Time.current
                         }])
    end
    # rubocop:enable Rails/SkipsModelValidations

    it 'is the partial unique index, not the before_create callback, that enforces the invariant under a race' do
      first = create(:status, resource: post, resource_role: 'status', state: 'draft')
      expect(first.reload.is_prime).to be(true)

      # The rival insert runs in its own savepoint (`requires_new: true`).
      # On PostgreSQL, a failed statement poisons the enclosing transaction
      # until rollback -- without a savepoint here, the `first.reload` below
      # would raise `PG::InFailedSqlTransaction` instead of exercising the
      # actual assertion. SQLite doesn't need this, but it's harmless there.
      expect do
        ActiveRecord::Base.transaction(requires_new: true) do
          insert_rival_prime(resource: post, role: 'status', state: 'public')
        end
      end.to raise_error(ActiveRecord::RecordNotUnique)

      # The first row is untouched — proof the index rejected the second
      # INSERT outright rather than the callback resolving the conflict.
      expect(first.reload.is_prime).to be(true)
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
