class DataSubjectRequestPolicy < ApplicationPolicy
  def index?
    owner?
  end

  def show?
    owner?
  end

  def create?
    true
  end

  def update?
    owner?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(business_id: Current.business_id!)
    end
  end
end
