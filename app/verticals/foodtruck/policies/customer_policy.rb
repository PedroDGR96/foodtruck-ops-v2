# The registry is visible to all staff (a customer profile is part of order
# detail). Creating and editing customers is cashier/owner work; only the owner
# can archive (soft-delete) a customer.
class CustomerPolicy < ApplicationPolicy
  def index?
    staff?
  end

  def show?
    staff?
  end

  def new?
    create?
  end

  def edit?
    update?
  end

  def create?
    owner? || cashier?
  end

  def update?
    owner? || cashier?
  end

  def destroy?
    owner?
  end
end
