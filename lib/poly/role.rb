# frozen_string_literal: true

module Poly::Role
  extend ActiveSupport::Concern

  class_methods do
    # Declares a role column on a polymorphic belongs_to.
    #   poly_role :schedulable    -> expects schedulable_role column
    #   poly_role :resource       -> expects resource_role column
    def poly_role(assoc_name, max_length: 64, immutable: false)
      role_col = :"#{assoc_name}_role"

      validates role_col,
                presence: true,
                format: { with: /\A[a-z0-9_]+\z/ },
                length: { maximum: max_length }

      before_validation { public_send(:"#{role_col}=", public_send(role_col).to_s.strip.downcase.presence) }

      scope :for_role, ->(role) { where(role_col => role.to_s.strip.downcase) }
      poly_role_immutability!(role_col) if immutable
    end

    private

    def poly_role_immutability!(role_col)
      validate(on: :update) do
        errors.add(role_col, 'cannot be changed once set') if will_save_change_to_attribute?(role_col)
      end
    end
  end
end
