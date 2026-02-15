# frozen_string_literal: true

module Poly::Joins
  extend ActiveSupport::Concern

  included do
    define_polymorphic_joins!
  end

  class_methods do
    def define_polymorphic_joins!
      reflect_on_all_associations(:belongs_to).each do |assoc|
        next unless assoc.options[:polymorphic]

        reflection = assoc
        assoc_name = reflection.name
        method_name = :"joins_#{assoc_name}"

        next if singleton_class.method_defined?(method_name)

        define_singleton_method(method_name) do |klass|
          unless klass <= ActiveRecord::Base
            raise PolymorphicJoinError, "Expected an ActiveRecord model"
          end

          base_klass = klass.base_class

          unless join_allowed?(klass, as: assoc_name)
            raise PolymorphicJoinError,
                  "Polymorphic join requires #{base_klass} to declare: " \
                  "has_many :#{self.name.underscore.pluralize}, as: :#{assoc_name}"
          end

          source = arel_table
          target = base_klass.arel_table

          joins(
            source.join(target)
                  .on(source["#{assoc_name}_id"].eq(target[:id])
                    .and(source["#{assoc_name}_type"].eq(base_klass.name))
                  )
                  .join_sources
          )
        end
      end
    end

    private

    def join_allowed?(klass, as:)
      klass.reflect_on_all_associations.any? do |assoc|
        next false unless assoc.options[:as] == as
        next false unless %i[has_many has_one].include? assoc.macro

        assoc.klass == self
      end
    end
  end
end

class PolymorphicJoinError < StandardError; end
