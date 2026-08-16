# Orders are viewable by all staff. The POS (create/update/pay) is a
# cashier/owner surface. Cancelling an unpaid order is cashier work; cancelling
# an order that already reached the kitchen requires the owner.
class OrderPolicy < ApplicationPolicy
  def index?
    staff?
  end

  def show?
    staff?
  end

  def create?
    owner? || cashier?
  end

  def update?
    owner? || cashier?
  end

  def confirm?
    owner? || cashier?
  end

  def pay?
    owner? || cashier?
  end

  def cancel?
    if record.status.in?(%w[paid in_kitchen ready])
      owner?
    else
      owner? || cashier?
    end
  end

  def refund?
    return false unless owner? || cashier?
    return true unless record.refund_touches_closed_shift?

    owner?
  end

  def mark_out_for_delivery?
    owner? || cashier?
  end

  def mark_delivered?
    owner? || cashier?
  end

  def start_cooking?
    kitchen? || owner?
  end

  def mark_ready?
    kitchen? || owner?
  end
end
