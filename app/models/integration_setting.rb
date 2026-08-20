class IntegrationSetting < ApplicationRecord
  include BusinessScoped
  include TenantChild

  PROVIDER_KEYS = %w[payment_gateway messaging maps fiscal marketplace].freeze

  # Decision: credentials are intentionally stored as plaintext JSONB today (no
  # `encrypts :credentials`). Specs pin this contract. Add `encrypts` and update
  # the spec to assert ciphertext before shipping real provider credentials.
  before_validation :ensure_credentials_is_hash
  attribute :credentials, :jsonb, default: {}

  validates :provider_key, inclusion: { in: PROVIDER_KEYS }
  validates :provider_key, uniqueness: { scope: :business_id }

  scope :enabled, -> { where(enabled: true) }

  private

  def ensure_credentials_is_hash
    self.credentials = {} if credentials.nil?
  end
end
