# frozen_string_literal: true

module Poly::Role
  extend ActiveSupport::Concern

  class_methods do
    # Declares a role column on a polymorphic belongs_to.
    #   poly_role :schedulable    -> expects schedulable_role column
    #   poly_role :resource       -> expects resource_role column
    def poly_role(assoc_name, max_length: 64)
      role_col = :"#{assoc_name}_role"

      validates role_col,
                presence: true,
                format: { with: /\A[a-z0-9_]+\z/ },
                length: { maximum: max_length }

      before_validation do
        val = public_send(role_col)
        public_send(:"#{role_col}=", val.to_s.strip.downcase.presence) if val
      end

      scope :for_role, ->(role) { where(role_col => role.to_s) }
    end
  end
end
