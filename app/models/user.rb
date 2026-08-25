class User < ApplicationRecord
  include BusinessScoped

  ROLES = %w[owner cashier kitchen].freeze

  devise :database_authenticatable, :validatable, :timeoutable, :lockable, :trackable

  enum :role, ROLES.index_with(&:itself)

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false, unscoped: true }
  validates :role, inclusion: { in: ROLES }

  after_save :record_lock_change

  def self.serialize_from_session(key, salt)
    unscoped { super }
  end

  def self.find_first_by_auth_conditions(tainted_conditions, opts = {})
    unscoped { super }
  end

  # API tokens for this user (JSON:API bearer auth)
  has_many :tokens, -> { where(business_id: business_id) }, dependent: :delete_all

  # Tenants associated with this user (tenancy association)
  has_many :tenants, -> { where(business_id: business_id) }, dependent: :delete_all

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :inactive
  end

  def timeout_in
    self.class.timeout_in || 2.hours
  end

  private

  def record_lock_change
    return unless saved_change_to_locked_at?

    AuditLog.record!(
      action: locked_at? ? "user_locked" : "user_unlocked",
      resource: "user",
      resource_id: id,
      actor_id: id
    )
  end
end
