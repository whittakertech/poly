# frozen_string_literal: true

FactoryBot.define do
  factory :tagging do
    taggable factory: %i[post]
    taggable_role { 'primary' }
  end
end
