class PaymentPolicy < ApplicationPolicy
  def new?
    create?
  end

  def create?
    owner? || cashier?
  end

  def show?
    staff?
  end
end
