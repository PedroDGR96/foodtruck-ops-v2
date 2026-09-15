class IntegrationSetting < ApplicationRecord
  include BusinessScoped
  include TenantChild

  PROVIDER_KEYS = %w[payment_gateway messaging maps fiscal marketplace].freeze

  attribute :credentials, :jsonb, default: {}
  encrypts :credentials

  before_validation :ensure_credentials_is_hash

  validates :provider_key, inclusion: { in: PROVIDER_KEYS }
  validates :provider_key, uniqueness: { scope: :business_id }

  scope :enabled, -> { where(enabled: true) }

  private

  def ensure_credentials_is_hash
    self.credentials = {} if credentials.nil?
  end
end
