# frozen_string_literal: true

FactoryBot.define do
  factory :tagging do
    taggable factory: %i[post]
    taggable_label { 'primary' }
  end
end
