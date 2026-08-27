class CompliancePolicy < ApplicationPolicy
  def show?
    owner?
  end
end
