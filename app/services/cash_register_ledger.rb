# Records the expense movements that refunds create on the cash drawer.
# A refund of a cash payment hits the register the payment was originally
# recorded in: same-shift refunds land on the still-open shift, while refunds
# of a closed shift land on that closed register and flag its reconciliation as
# drifted (this is why closed-shift refunds require the owner role).
class CashRegisterLedger
  # `payments` must be captured before the refund flips their status, otherwise
  # the "successful" scope would no longer match the refunded legs.
  def self.record_refunds!(payments:, order:, actor: nil)
    payments.each do |payment|
      next unless payment.cash_register

      CashRegisterService.record_movement!(
        register: payment.cash_register,
        movement_type: :expense,
        category: :refund,
        amount: payment.amount,
        reason: I18n.t("cash_registers.refund_reason", order_id: order.id),
        actor: actor,
        order: order,
        payment: payment
      )
    end
  end
end
