# frozen_string_literal: true

FactoryBot.define do
  factory :comment do
    body { 'Test comment' }
    commentable factory: %i[post]
  end
end
