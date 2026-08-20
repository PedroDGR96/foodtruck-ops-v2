class Payment < ApplicationRecord
  include BusinessScoped
  include TenantChild

  enum :method, { cash: "cash", pix: "pix", card: "card" }
  enum :status, { succeeded: "succeeded", refunded: "refunded" }, default: :succeeded

  belongs_to :order
  belongs_to :cash_register, optional: true

  validates :amount, numericality: { greater_than: 0 }
  validates_parent_business_for :order, :cash_register
  validate :cannot_exceed_order_balance

  scope :successful, -> { where(status: :succeeded) }

  private

  def cannot_exceed_order_balance
    return unless order.present? && order.total.present?

    paid_so_far = order.payments.successful.where.not(id: id).sum(:amount)
    if amount.present? && (paid_so_far + amount) > order.total
      errors.add(:amount, :exceeds_order_total)
    end
  end
end
