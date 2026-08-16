# frozen_string_literal: true

# Card-side concern. Turns a polymorphic, role-discriminated model (the "card"
# model, e.g. Status) into a stack where the most-recently created card per
# (resource, role) is the current "prime" — the top of the stack. The
# contract is immutable payload, mutable linkage/index metadata: prior rows
# are never deleted, but their `is_prime` and `superseded_by_id` columns are
# mutated in place when a new card supersedes them — this is not a literally
# append-only/immutable-row stack.
#
#   class Status < ApplicationRecord
#     belongs_to :resource, polymorphic: true
#     include Poly::Joins
#     include Poly::Stack
#     poly_stack :resource
#   end
#
# Poly::Stack builds on Poly::Role (the resource_role discriminator) and adds
# only `is_prime` (the enforced golden-child marker) and `superseded_by_id`
# (an unconstrained audit edge). It is deliberately payload agnostic: it does
# not define the payload column, the actor, or the reason — those belong to the
# host model. The parent-side accessor macro (`has_stack`) is the consumer's to
# write, the way Midas writes `has_coin` on Poly::Role — see the README.
module Poly::Stack
  extend ActiveSupport::Concern
  include Poly::Role

  included do
    class_attribute :poly_stack_association, instance_accessor: false
  end

  class_methods do
    # Declares the stack. `assoc_name` is the polymorphic belongs_to whose
    # *_role column discriminates independent stacks on the same table.
    def poly_stack(assoc_name, max_length: 64)
      poly_role(assoc_name, max_length: max_length)
      self.poly_stack_association = assoc_name.to_sym

      scope :prime, -> { where(is_prime: true) }

      before_create :poly_stack_seize_prime
      after_create  :poly_stack_chain_superseded
    end

    def poly_stack_columns
      assoc = poly_stack_association
      { type: :"#{assoc}_type", id: :"#{assoc}_id", role: :"#{assoc}_role" }
    end
  end

  private

  # Demote the current prime (if any) so this card can take its place, and
  # remember it so the supersession edge can be linked once we have an id.
  # Runs before insert: at INSERT time there is exactly one is_prime row, so
  # the partial unique index is satisfied (zero primes momentarily is legal).
  #
  # Concurrency boundary: this demote-then-insert sequence is NOT wrapped in
  # an explicit row lock or transaction. Two concurrent writers racing the
  # same (resource, role) can both read the same prior prime, both demote it
  # via #update_columns, and both attempt to insert with is_prime: true. The
  # second writer's INSERT then raises ActiveRecord::RecordNotUnique — not
  # here in the callback, but afterward, once ActiveRecord issues the actual
  # INSERT. It is the partial unique index (`poly_prime_index` /
  # `index_#{table}_prime`, see lib/poly/migration.rb), not this callback,
  # that actually enforces "at most one prime per (resource, role)" under a
  # race. Poly::Stack does not retry internally; see README's "Poly::Stack"
  # section for the recommended caller-side rescue-and-retry pattern.
  def poly_stack_seize_prime
    cols = self.class.poly_stack_columns
    @poly_stack_superseded = self.class
                                 .where(cols[:type] => self[cols[:type]],
                                        cols[:id] => self[cols[:id]],
                                        cols[:role] => self[cols[:role]])
                                 .prime
                                 .first
    @poly_stack_superseded&.update_columns(is_prime: false)
    self.is_prime = true
  end

  # Audit edge (decoration, unconstrained): the old prime points forward to the
  # card that replaced it. Safe to run after insert since it carries no index.
  def poly_stack_chain_superseded
    @poly_stack_superseded&.update_columns(superseded_by_id: id)
  end
end
