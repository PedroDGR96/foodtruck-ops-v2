FactoryBot.define do
  factory :privacy_incident do
    association :business
    sequence(:title) { |n| "Incidente #{n}" }
    description { "Vazamento de dados detectado no sistema." }
    severity { "low" }
    status { "detected" }
    affected_data_categories { %w[email phone] }
    affected_subjects_count { 0 }
    detected_at { Time.current }

    trait :medium_severity do
      severity { "medium" }
    end

    trait :high_severity do
      severity { "high" }
    end

    trait :critical do
      severity { "critical" }
    end

    trait :investigating do
      status { "investigating" }
    end

    trait :contained do
      status { "contained" }
      remediation_notes { "Acesso revogado, credenciais rotacionadas." }
    end

    trait :notified do
      status { "notified" }
      anpd_notified_at { Time.current }
    end

    trait :resolved do
      status { "resolved" }
      remediation_notes { "Incidente resolvido. Todas as medidas corretivas implementadas." }
    end

    trait :anpd_overdue do
      detected_at { 3.days.ago }
      anpd_notification_deadline { 2.days.ago }
    end
  end
end
