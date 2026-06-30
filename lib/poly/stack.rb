# frozen_string_literal: true

# Card-side concern. Turns a polymorphic, role-discriminated model (the "card"
# model, e.g. Status) into an append-only stack where the most-recently created
# card per (resource, role) is the current "prime" — the top of the stack.
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
