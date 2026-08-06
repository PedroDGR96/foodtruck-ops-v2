# A single cash drawer entry on a shift: manual income (cash drop) or expense
# (refund, payout), always positive and always tied to a cash register. Refund
# movements additionally link back to the order and payment that originated
# them so shift reconciliation can be audited end to end.
class CashMovement < ApplicationRecord
  include BusinessScoped
  include TenantChild

  enum :movement_type, { income: "income", expense: "expense" }
  enum :category, {
    refund: "refund",
    cash_drop: "cash_drop",
    payout: "payout",
    other_income: "other_income",
    other_expense: "other_expense"
  }

  belongs_to :cash_register
  belongs_to :order, optional: true
  belongs_to :payment, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  validates :amount, numericality: { greater_than: 0 }
  validates :reason, presence: true
  validates_parent_business_for :cash_register, :order, :payment

  scope :income, -> { where(movement_type: :income) }
  scope :expense, -> { where(movement_type: :expense) }
  scope :recent, -> { order(created_at: :desc) }
end
