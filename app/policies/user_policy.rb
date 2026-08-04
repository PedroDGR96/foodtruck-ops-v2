class UserPolicy < ApplicationPolicy
  def index?
    owner?
  end

  def new?
    owner?
  end

  def create?
    owner?
  end

  def edit?
    owner?
  end

  def update?
    owner?
  end
end
