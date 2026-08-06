# An order is the root of a sale: line items with price snapshots, payments and
# an immutable event timeline. Status transitions are driven exclusively by
# OrderLifecycle so every move is validated and audited.
class Order < ApplicationRecord
  include BusinessScoped
  include TenantChild

  enum :order_type, { local: "local", delivery: "delivery", pickup: "pickup" }, default: :local
  enum :status, {
    draft: "draft",
    open: "open",
    partially_paid: "partially_paid",
    paid: "paid",
    in_kitchen: "in_kitchen",
    ready: "ready",
    completed: "completed",
    cancelled: "cancelled",
    refunded: "refunded"
  }, default: :draft
  enum :kitchen_status, { pending: "pending", in_progress: "in_progress", done: "done" }, default: :pending, prefix: true
  enum :payment_status, { pending: "pending", partially_paid: "partially_paid", paid: "paid", refunded: "refunded" }, default: :pending, prefix: true

  belongs_to :user, optional: true
  belongs_to :customer, optional: true
  has_many :order_items, dependent: :restrict_with_exception
  has_many :order_item_addons, through: :order_items
  has_many :payments, dependent: :restrict_with_exception
  has_many :order_events, dependent: :restrict_with_exception

  validates :subtotal, :tax, :total, numericality: { greater_than_or_equal_to: 0 }
  validate :totals_consistent
  validate :payment_status_consistent
  validates_parent_business_for :customer

  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: %i[paid in_kitchen ready]) }
  scope :purchases, -> { where.not(status: %i[draft cancelled refunded]) }

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

  def recalculate_totals!
    items = order_items.reset
    addon_totals = order_item_addons.group(:order_item_id).sum(:price)
    new_subtotal = items.sum do |item|
      ((item.unit_price + addon_totals.fetch(item.id, 0.0)).round(2) * item.quantity).round(2)
    end.round(2)

    update_columns(subtotal: new_subtotal, total: (new_subtotal + tax).round(2))
  end

  private

  def totals_consistent
    return unless persisted? && total_changed? || subtotal_changed?

    expected = (subtotal + tax).round(2)
    errors.add(:total, :inconsistent) unless total == expected
  end

  def payment_status_consistent
    return unless payment_status == "paid"

    errors.add(:payment_status, :inconsistent) if paid_amount < total
  end
end
