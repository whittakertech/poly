# frozen_string_literal: true

module Poly::Owners
  extend ActiveSupport::Concern

  class_methods do
    # Declares owner columns populated before validation.
    #   poly_owner :resource, owner: -> { ledger.account }
    #   poly_owner :resource, owner: :account
    def poly_owner(assoc_name, owner:, type_column: :owner_type, id_column: :owner_id,
                   allow_nil: true, immutable: false)
      raise ArgumentError, 'owner is required' if owner.nil?

      assoc = reflect_on_association(assoc_name.to_sym)
      unless assoc&.macro == :belongs_to && assoc.options[:polymorphic]
        raise ArgumentError, "#{name} must declare belongs_to :#{assoc_name}, polymorphic: true"
      end

      before_validation { Poly::Owners.apply_owner(self, owner, type_column, id_column, allow_nil: allow_nil) }
      poly_owner_immutability!(type_column, id_column) if immutable
    end

    private

    def poly_owner_immutability!(type_column, id_column)
      validate(on: :update) do
        if will_save_change_to_attribute?(type_column) || will_save_change_to_attribute?(id_column)
          errors.add(:base, 'owner cannot be changed once set')
        end
      end
    end
  end

  def self.apply_owner(record, owner, type_column, id_column, allow_nil: true)
    resolved = resolve_owner(record, owner)
    if resolved.nil?
      assign_nil_owner(record, type_column, id_column, allow_nil: allow_nil)
    elsif resolved.is_a?(ActiveRecord::Base)
      raise ArgumentError, 'owner must be persisted' unless resolved.persisted?

      record.public_send(:"#{type_column}=", resolved.class.base_class.name)
      record.public_send(:"#{id_column}=", resolved.id)
    else
      raise ArgumentError, "owner must resolve to an ActiveRecord::Base, got #{resolved.class}"
    end
  end

  def self.assign_nil_owner(record, type_column, id_column, allow_nil:)
    raise ArgumentError, 'owner resolved to nil' unless allow_nil

    record.public_send(:"#{type_column}=", nil)
    record.public_send(:"#{id_column}=", nil)
  end

  def self.resolve_owner(record, owner)
    case owner
    when Proc
      record.instance_exec(&owner)
    when Symbol, String
      record.public_send(owner)
    else
      owner
    end
  end
end
