# An order is the root of a sale: line items with price snapshots, payments and
# an immutable event timeline. Status transitions are driven exclusively by
# OrderLifecycle so every move is validated and audited.
class Order < ApplicationRecord
  include BusinessScoped
  include TenantChild

  # Batch limits for kitchen board rendering so eager_load scopes never pull
  # unbounded result sets into memory (prevents runaway loops when the queue
  # grows large).
  KITCHEN_BATCH_LIMIT = 200

  enum :order_type, { local: "local", delivery: "delivery", pickup: "pickup" }, default: :local
  enum :status, {
    draft: "draft",
    open: "open",
    partially_paid: "partially_paid",
    paid: "paid",
    in_kitchen: "in_kitchen",
    ready: "ready",
    delivered: "delivered",
    completed: "completed",
    cancelled: "cancelled",
    refunded: "refunded"
  }, default: :draft
  enum :kitchen_status, { pending: "pending", in_progress: "in_progress", done: "done" }, default: :pending, prefix: true
  enum :payment_status, { pending: "pending", partially_paid: "partially_paid", paid: "paid", refunded: "refunded" }, default: :pending, prefix: true

  before_create :assign_order_number

  belongs_to :user, optional: true
  belongs_to :customer, optional: true
  has_many :order_items, dependent: :restrict_with_exception
  has_many :order_item_addons, through: :order_items
  has_many :payments, dependent: :restrict_with_exception
  has_many :order_events, dependent: :restrict_with_exception
  has_one :delivery_address, dependent: :restrict_with_exception, validate: true
  has_one :delivery, dependent: :restrict_with_exception

  validates :subtotal, :tax, :total, :delivery_fee, numericality: { greater_than_or_equal_to: 0 }
  validate :totals_consistent
  validate :payment_status_consistent
  validate :delivery_address_required_for_delivery
  validates_parent_business_for :customer

  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: %i[paid in_kitchen ready delivered]) }
  scope :kitchen_queue, -> do
    where(status: %i[paid in_kitchen])
      .eager_load(order_items: :order_item_addons)
      .order(Arel.sql("CASE kitchen_status WHEN 'in_progress' THEN 0 ELSE 1 END"), created_at: :asc)
      .limit(KITCHEN_BATCH_LIMIT)
  end
  scope :purchases, -> { where.not(status: %i[draft cancelled refunded]) }
  scope :kitchen_completed, -> do
    where(kitchen_status: :done, status: :ready)
      .eager_load(order_items: :order_item_addons)
      .order(created_at: :desc)
      .limit(KITCHEN_BATCH_LIMIT)
  end

  def paid_amount
    payments.where(status: :succeeded).sum(:amount)
  end

  def balance_due
    (total - paid_amount).round(2)
  end

  def fully_paid?
    paid_amount >= total
  end

  def pending_payment?
    payment_status.in?(%w[pending partially_paid])
  end

  def paid?
    status == "paid"
  end

  # A refund of cash payments that were recorded in a closed shift changes that
  # shift's books after the fact, so it needs owner authorization (see
  # OrderPolicy and CashRegisterLedger).
  def refund_touches_closed_shift?
    cash_payments_refundable.any? { |payment| payment.cash_register&.closed? }
  end

  def cash_payments_refundable
    payments.cash.successful.to_a
  end

  def recalculate_totals!
    items = order_items.reset
    addon_totals = order_item_addons.group(:order_item_id).sum(:price)
    new_subtotal = items.sum do |item|
      ((item.unit_price + addon_totals.fetch(item.id, 0.0)).round(2) * item.quantity).round(2)
    end.round(2)

    update_columns(subtotal: new_subtotal, total: (new_subtotal + tax + delivery_fee).round(2))
  end

  def translated_status
    I18n.t("orders.status.#{status}", locale: :pt_br)
  end

  private

  # Human-friendly sequential number per business (shown as #123 instead of
  # the UUID). Unique index on [business_id, number] guards against races;
  # a collision raises RecordNotUnique and the caller retries.
  def assign_order_number
    return if number.present?

    self.number = self.class.where(business_id: business_id).maximum(:number).to_i + 1
  end

  def totals_consistent
    return unless persisted? && total_changed? || subtotal_changed?

    expected = (subtotal + tax + delivery_fee).round(2)
    errors.add(:total, :inconsistent) unless total == expected
  end

  def delivery_address_required_for_delivery
    return unless delivery?

    errors.add(:delivery_address, :blank) if delivery_address.nil?
  end

  def payment_status_consistent
    return unless payment_status == "paid"
    return unless Current.business
    return if payments.empty?

    balance = (total - paid_amount).round(2)
    errors.add(:payment_status, :inconsistent) unless balance <= 0
  end
end
