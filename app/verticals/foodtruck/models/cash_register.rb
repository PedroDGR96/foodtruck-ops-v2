# A daily summary of all cash operations across the POS system. Tracks the
# current day's cash register balance (total open cash across all cashiers)
# and total sales (sum of cash payments across all cashiers). This is used
# for reconciliation: expected closing (opening + cash sales + net movements)
# compared to the actual drawer count and any drift is recorded. A closed
# register that receives a late refund movement is flagged as drifted so the
# reconciliation never silently goes stale.
class CashRegister < ApplicationRecord
  class ShiftError < StandardError; end

  include BusinessScoped
  include TenantChild

  enum :status, { open: "open", closed: "closed" }, default: :open

  belongs_to :user
  has_many :cash_movements, dependent: :restrict_with_exception
  has_many :payments, dependent: :restrict_with_exception
  has_one :cash_register, dependent: :restrict_with_exception

  validates :opening_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :actual_closing_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :single_open_shift_per_cashier
  validate :actual_closing_amount_required_to_close
  validate :opened_at_present

  scope :open, -> { where(status: :open) }
  scope :closed, -> { where(status: :closed) }

  before_validation :assign_opened_at, on: :create

  def close!(actual_closing_amount:, actor: nil)
    raise ShiftError, I18n.t("cash_registers.errors.already_closed") if closed?

    amount = actual_closing_amount.to_s.strip.presence&.to_d
    self.actual_closing_amount = amount
    self.expected_closing_amount = expected_closing
    if amount
      self.drift = (amount - expected_closing_amount).round(2)
      self.reconciled = drift.zero?
    end
    self.closed_at = Time.current
    self.status = :closed

    save!
    AuditLog.record!(
      action: "shift_closed",
      resource: "cash_register",
      resource_id: id,
      actor: actor,
      metadata: { expected: expected_closing_amount.to_s, actual: actual_closing_amount.to_s, drift: drift.to_s }
    )
    self
  end

  def expected_closing
    (opening_amount + cash_sales + movement_balance).round(2)
  end

  def cash_sales
    payments.cash.sum(:amount)
  end

  def movement_balance
    cash_movements.sum("CASE WHEN movement_type = 'income' THEN amount ELSE -amount END")
  end

  def flag_reconciliation!
    return unless closed?

    update_columns(
      expected_closing_amount: expected_closing,
      drift: (actual_closing_amount - expected_closing).round(2),
      reconciled: actual_closing_amount == expected_closing
    )
  end

  private

  def assign_opened_at
    self.opened_at ||= Time.current
  end

  def single_open_shift_per_cashier
    return unless open?

    if CashRegister.open.where(user_id: user_id).where.not(id: id).exists?
      errors.add(:base, :already_open_shift)
    end
  end

  def actual_closing_amount_required_to_close
    return unless status == "closed"

    errors.add(:actual_closing_amount, :blank) if actual_closing_amount.nil?
  end

  def opened_at_present
    errors.add(:opened_at, :blank) if opened_at.nil?
  end
end
