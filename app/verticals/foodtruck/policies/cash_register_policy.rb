# Shift bookkeeping is cashier/owner work. Opening a shift is the cashier's
# own; closing and recording movements are restricted to the shift's cashier
# (the owner may do both on any shift). Post-close movement recording is the
# owner's correction surface only.
class CashRegisterPolicy < ApplicationPolicy
  def index?
    staff?
  end

  def show?
    staff?
  end

  def new?
    create?
  end

  def create?
    owner? || cashier?
  end

  def close?
    return true if owner?

    cashier? && record.user == user && record.open?
  end

  def record_movement?
    return true if owner?

    cashier? && record.open? && record.user == user
  end
end
