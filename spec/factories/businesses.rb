FactoryBot.define do
  factory :business do
    sequence(:name) { |number| "Business #{number}" }
    currency { "BRL" }
    timezone { "America/Sao_Paulo" }
    active { true }
  end
end
