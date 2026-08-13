class IntegrationSetting < ApplicationRecord
  include BusinessScoped
  include TenantChild

  PROVIDER_KEYS = %w[payment_gateway messaging maps fiscal marketplace].freeze

  attribute :credentials, :jsonb, default: {}

  validates :provider_key, inclusion: { in: PROVIDER_KEYS }
  validates :provider_key, uniqueness: { scope: :business_id }

  scope :enabled, -> { where(enabled: true) }
end
