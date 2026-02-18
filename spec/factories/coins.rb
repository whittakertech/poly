# frozen_string_literal: true

FactoryBot.define do
  factory :coin do
    ledger
    resource factory: %i[post]
    resource_role { 'primary' }
  end
end
