class BusinessPolicy < ApplicationPolicy
  def edit?
    owner?
  end

  def update?
    owner?
  end
end
