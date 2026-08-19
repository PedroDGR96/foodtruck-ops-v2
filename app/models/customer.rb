# A customer is a person the business serves: registry data plus a purchase
# history computed from the orders attached to them. Phones are stored
# normalized (digits, Brazilian national format) and unique per business.
class Customer < ApplicationRecord
  include BusinessScoped
  include SoftDelete

  has_many :orders, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :phone, format: { with: /\A\d{10,11}\z/ }, allow_blank: true
  validates :phone, uniqueness: { scope: :business_id, conditions: -> { where(discarded_at: nil) } }, allow_blank: true

  before_validation :normalize_phones

  scope :ordered, -> { order(:name) }

  def self.normalize_phone(raw)
    digits = raw.to_s.gsub(/[^\d]/, "")
    digits = digits.sub(/^55/, "") if digits.length > 11
    digits = digits.sub(/^0/, "") if digits.length > 11
    digits
  end

  def self.search(term)
    return none if term.blank?

    # NOTE: For production use with many customers, add an index on name via migration.
    # CREATE INDEX idx_customers_name ON customers(name);
    pattern = "%#{term.to_s.strip}%"
    where("name ILIKE :q OR phone ILIKE :q", q: pattern)
  end

  private

  def normalize_phones
    self.phone = normalized_or_nil(phone)
    self.whatsapp = normalized_or_nil(whatsapp)
  end

  def normalized_or_nil(value)
    self.class.normalize_phone(value).presence
  end
end
