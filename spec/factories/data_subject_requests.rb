FactoryBot.define do
  factory :data_subject_request do
    association :business
    user { nil }
    sequence(:data_subject_email) { |n| "titular#{n}@example.com" }
    request_type { "access" }
    status { "pending" }
    description { "Solicito acesso aos meus dados pessoais." }
    ip_address { "127.0.0.1" }
    user_agent { "Mozilla/5.0" }

    trait :correction do
      request_type { "correction" }
    end

    trait :deletion do
      request_type { "deletion" }
    end

    trait :portability do
      request_type { "portability" }
    end

    trait :revocation do
      request_type { "revocation" }
    end

    trait :in_progress do
      status { "in_progress" }
    end

    trait :completed do
      status { "completed" }
      completed_at { Time.current }
      response_notes { "Dados exportados e enviados por e-mail." }
    end

    trait :rejected do
      status { "rejected" }
      completed_at { Time.current }
      response_notes { "Solicitação não atende aos requisitos da LGPD." }
    end

    trait :overdue do
      deadline_at { 1.day.ago }
    end

    trait :due_soon do
      deadline_at { 2.days.from_now }
    end
  end
end
