# Orchestrates shift open/close and cash movements. Every mutation is
# persisted, audited, and — for post-close bookkeeping — re-flags the closed
# register's reconciliation. Refund movements from the order lifecycle go
# through here too, so all money entries share one code path.
class CashRegisterService
  def self.open!(register:, actor: nil)
    raise ArgumentError, "Register already open" unless register.open?
    raise ArgumentError, "Business not active" unless register.business.active?
    register.save!
    AuditLog.record!(
      action: "shift_opened",
      resource: "cash_register",
      resource_id: register.id,
      actor: actor,
      metadata: { opening_amount: register.opening_amount&.to_s || "0" }
    )
    register
  end

  def self.close!(register:, actual_closing_amount:, actor: nil)
    register.close!(actual_closing_amount: actual_closing_amount, actor: actor)
  end

  def self.record_movement!(register:, movement_type:, category:, amount:, reason:, actor: nil, order: nil, payment: nil)
    movement = register.cash_movements.build(
      movement_type: movement_type,
      category: category,
      amount: amount.to_d,
      reason: reason,
      order: order,
      payment: payment,
      created_by: actor
    )
    movement.save!
    register.flag_reconciliation! if register.closed?
    AuditLog.record!(
      action: "cash_movement",
      resource: "cash_movement",
      resource_id: movement.id,
      actor: actor,
      metadata: {
        cash_register_id: register.id,
        movement_type: movement.movement_type,
        category: movement.category,
        amount: movement.amount.to_s
      }
    )
    movement
  end
end
