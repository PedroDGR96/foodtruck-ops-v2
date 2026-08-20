# API tokens are bearer credentials: a SHA-256 digest is stored, the raw value
# is shown once at issue time. Tokens are intentionally NOT row-level-secured:
# authentication runs before any tenant context exists, so the lookup must be
# able to see across businesses. The business is still recorded for attribution.
class Token < ApplicationRecord
  SCOPES = %w[reader writer admin].freeze

  belongs_to :business
  belongs_to :user

  validates :scope, inclusion: { in: SCOPES }
  validates :name, presence: true

  before_validation :set_business_from_user
  before_validation :ensure_token_digest

  scope :active, -> { where(active: true) }

  def self.digest(raw)
    Digest::SHA256.hexdigest(raw.to_s)
  end

  def self.authenticate(raw)
    return nil if raw.blank?

    find_by(token_digest: digest(raw))
  end

  def self.issue!(user:, scope:, name:)
    raw = SecureRandom.hex(32)
    token = new(user: user, scope: scope, name: name, token_digest: digest(raw))
    token.save!
    [ token, raw ]
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  private

  def set_business_from_user
    self.business_id ||= user&.business_id
  end

  def ensure_token_digest
    self.token_digest ||= self.class.digest(SecureRandom.hex(32))
  end
end
