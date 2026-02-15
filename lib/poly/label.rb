# frozen_string_literal: true

module Poly::Label
  extend ActiveSupport::Concern

  class_methods do
    # Declares a label column on a polymorphic belongs_to.
    #   labeled_poly :schedulable    -> expects schedulable_label column
    #   labeled_poly :resource       -> expects resource_label column
    def labeled_poly(assoc_name, max_length: 64)
      label_col = :"#{assoc_name}_label"

      validates label_col,
                presence: true,
                format: { with: /\A[a-z0-9_]+\z/ },
                length: { maximum: max_length }

      before_validation do
        val = public_send(label_col)
        public_send(:"#{label_col}=", val.to_s.strip.downcase.presence) if val
      end

      scope :for_label, ->(label) { where(label_col => label.to_s) }
    end
  end
end
