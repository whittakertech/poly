# frozen_string_literal: true

FactoryBot.define do
  factory :status do
    resource factory: %i[post]
    resource_role { 'status' }
    state { 'public' }
  end
end
