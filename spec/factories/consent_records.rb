FactoryBot.define do
  factory :consent_record do
    association :business
    user { nil }
    sequence(:data_subject_email) { |n| "user#{n}@example.com" }
    consent_type { "privacy_policy" }
    consent_version { "1.0" }
    consent_text_hash { Digest::SHA256.hexdigest("privacy policy v1.0 text") }
    granted { true }
    ip_address { "127.0.0.1" }
    user_agent { "Mozilla/5.0" }

    trait :withdrawn do
      granted { false }
      withdrawn_at { 1.day.ago }
    end

    trait :marketing do
      consent_type { "marketing" }
    end

    trait :analytics do
      consent_type { "analytics" }
    end

    trait :with_user do
      association :user
      data_subject_email { nil }
    end
  end
end
